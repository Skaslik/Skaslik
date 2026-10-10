/// «Вместе» additions: list checklists on notes, who added a loyalty card.
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  group('Note checklist', () {
    late Replica a, b;
    late NotesRepo ra, rb;
    setUp(() {
      // One wall clock moving forward, as on two real phones. (Writes in
      // the very same millisecond are a replica edge case — see the note
      // in the Phase 6 summary.)
      var t = 1000;
      int clock() => t += 5;
      a = Replica('A', clock: clock);
      b = Replica('B', clock: clock);
      ra = NotesRepo(a);
      rb = NotesRepo(b);
      ra.upsert(const Note(id: 'n1', title: 'На выходные', at: 1));
    });

    void sync() {
      b.mergeIn(a.allOps());
      a.mergeIn(b.allOps());
    }

    test('add items, tick one; order by when added', () {
      ra.addItem('n1', const ChecklistItem(id: 'milk', text: 'Молоко', at: 10));
      ra.addItem('n1', const ChecklistItem(id: 'bread', text: 'Хлеб', at: 20));
      ra.setDone('n1', 'milk', done: true, by: 'A', at: 30);
      final items = ra.items('n1');
      expect(items.map((i) => i.text), ['Молоко', 'Хлеб']);
      expect(items.first.done, isTrue);
      expect(items.first.by, 'A');
      expect(items.last.done, isFalse);
    });

    test('each partner ticks a different item → both stay ticked', () {
      ra.addItem('n1', const ChecklistItem(id: 'milk', text: 'Молоко', at: 10));
      ra.addItem('n1', const ChecklistItem(id: 'bread', text: 'Хлеб', at: 20));
      sync();
      ra.setDone('n1', 'milk', done: true, by: 'A', at: 30);
      rb.setDone('n1', 'bread', done: true, by: 'B', at: 31);
      sync();
      for (final r in [ra, rb]) {
        final m = {for (final i in r.items('n1')) i.id: i};
        expect(m['milk']!.done && m['milk']!.by == 'A', isTrue);
        expect(m['bread']!.done && m['bread']!.by == 'B', isTrue);
      }
    });

    test('both toggle the same item at once → the phones agree', () {
      ra.addItem('n1', const ChecklistItem(id: 'eggs', text: 'Яйца', at: 10));
      sync();
      ra.setDone('n1', 'eggs', done: true, by: 'A', at: 40);
      rb.setDone('n1', 'eggs', done: false, by: 'B', at: 40);
      sync();
      final x = ra.items('n1').single, y = rb.items('n1').single;
      expect(x.done, y.done);
      expect(x.by, y.by);
    });

    test('removing an item hides it; the note stays', () {
      ra.addItem('n1', const ChecklistItem(id: 'bulb', text: 'Лампочка', at: 10));
      ra.removeItem('n1', 'bulb');
      expect(ra.items('n1'), isEmpty);
      expect(ra.get('n1'), isNotNull);
    });

    test('older app versions still read the note (checklist ignored)', () {
      ra.addItem('n1', const ChecklistItem(id: 'x', text: 'X', at: 10));
      final n = Note.fromFields('n1', a.entity('note:n1')!)!;
      expect(n.title, 'На выходные');
    });
  });

  group('LoyaltyCard.addedBy', () {
    test('round-trip, and old cards parse without it', () {
      final c = LoyaltyCard(
          id: 'c1',
          merchantName: 'Пятёрочка',
          category: CardCategory.supermarket,
          barcodeType: BarcodeType.ean13,
          barcodeValue: '4601234567893',
          addedBy: 'B');
      expect(LoyaltyCard.fromFields('c1', c.toFields())!.addedBy, 'B');
      final old = LoyaltyCard.fromFields(
          'c2', {'merchant': 'Магнит', 'barcode': '4630041552108', 'type': 'ean13'})!;
      expect(old.addedBy, isNull);
    });
  });
}
