/// Additive CalEvent fields: who created, who last edited, shared (I8).
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 10, 8, 19, 30);

  test('round-trip keeps owner, createdAt, editedBy/At and shared', () {
    final e = CalEvent(
      id: 'e1',
      title: 'Ужин у мамы Софии',
      start: start,
      ownerId: 'B',
      createdAt: 100,
      editedBy: 'A',
      editedAt: 200,
      shared: true,
    );
    final back = CalEvent.fromFields('e1', e.toFields())!;
    expect(back.ownerId, 'B');
    expect(back.createdAt, 100);
    expect(back.editedBy, 'A');
    expect(back.editedAt, 200);
    expect(back.shared, isTrue);
  });

  test('an event written by an older app version still parses', () {
    final legacy = {
      'title': 'Стоматолог',
      'startTs': '${start.millisecondsSinceEpoch}',
      'allDay': '0',
      'recur': 'none',
      'remind': '60',
    };
    final e = CalEvent.fromFields('old', legacy)!;
    expect(e.ownerId, isNull);
    expect(e.createdAt, isNull);
    expect(e.editedBy, isNull);
    expect(e.editedAt, isNull);
    expect(e.shared, isFalse);
  });

  test('absent optional fields are not written', () {
    final f = CalEvent(id: 'e', title: 't', start: start).toFields();
    expect(f.containsKey('owner'), isFalse);
    expect(f.containsKey('editedBy'), isFalse);
    expect(f['shared'], '0');
  });

  test('copyWith changes only what is given', () {
    final e = CalEvent(id: 'e', title: 'Йога', start: start, ownerId: 'B');
    final c = e.copyWith(title: 'Йога вечером', editedBy: 'A', editedAt: 5);
    expect(c.title, 'Йога вечером');
    expect(c.ownerId, 'B');
    expect(c.start, start);
    expect(c.editedBy, 'A');
  });

  test('two phones: A creates, B edits the title → owner A, edited by B', () {
    final a = Replica('A'), b = Replica('B');
    final ra = CalendarRepo(a), rb = CalendarRepo(b);
    ra.upsert(CalEvent(
        id: 'e', title: 'Казань', start: start, ownerId: 'A', createdAt: 1));
    b.mergeIn(a.allOps());
    final got = rb.get('e')!;
    rb.upsert(got.copyWith(title: 'Казань, поезд', editedBy: 'B', editedAt: 2));
    a.mergeIn(b.allOps());
    final merged = ra.get('e')!;
    expect(merged.title, 'Казань, поезд');
    expect(merged.ownerId, 'A');
    expect(merged.editedBy, 'B');
    expect(rb.get('e')!.title, merged.title);
  });
}
