/// The pair's profile, synced like any domain (no secrets in it).
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  const misha = Member(
      deviceId: 'A', name: 'Михаил', addressName: 'Миша',
      gender: MemberGender.m, color: 'michael');
  const sonya = Member(
      deviceId: 'B', name: 'София', addressName: 'Соня',
      gender: MemberGender.f, color: 'sofia');

  test('member round-trip; partner found after a merge', () {
    final a = Replica('A'), b = Replica('B');
    ProfileRepo(a).upsertMember(misha);
    ProfileRepo(b).upsertMember(sonya);
    a.mergeIn(b.allOps());
    final pa = ProfileRepo(a);
    expect(pa.member('A')!.addressName, 'Миша');
    expect(pa.partnerOf('A')!.name, 'София');
    expect(pa.partnerOf('A')!.gender, MemberGender.f);
    expect(pa.partnerOf('A')!.color, 'sofia');
    expect(ProfileRepo(b).partnerOf('B'), isNull); // not merged there yet
  });

  test('relationship start: days together and to the anniversary', () {
    final p = ProfileRepo(Replica('A'));
    expect(p.since(), isNull);
    p.setSince(DateTime(2022, 10, 10));
    expect(p.since(), DateTime(2022, 10, 10));
    final now = DateTime(2026, 10, 8, 21);
    expect(p.daysTogether(now), 1459);
    expect(p.daysToAnniversary(now), 2);
    expect(p.daysToAnniversary(DateTime(2026, 10, 10, 9)), 0);
  });

  test('29 February start: the anniversary falls on 28 February', () {
    final p = ProfileRepo(Replica('A'))..setSince(DateTime(2024, 2, 29));
    expect(p.daysToAnniversary(DateTime(2025, 2, 27)), 1);
  });

  test('unknown gender or colour fall back safely', () {
    final m = Member.fromFields('C', {'name': 'Аня'})!;
    expect(m.gender, MemberGender.m);
    expect(m.addressName, 'Аня');
    expect(m.color, isNull);
    expect(Member.fromFields('D', const {}), isNull);
  });

  test('capsule: who sealed it (additive)', () {
    const c = Capsule(id: 'c1', title: 'Письмо', sealDate: 5, from: 'B');
    expect(Capsule.fromFields('c1', c.toFields())!.from, 'B');
    expect(Capsule.fromFields('c2', {'seal': '5', 'title': 'x'})!.from, isNull);
  });
}
