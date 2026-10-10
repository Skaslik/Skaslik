/// Профиль пары: имена, обращение, род, цвет каждого и дата начала
/// отношений. Синхронизируется как обычный домен; секретов здесь нет.
///
/// Сущности: `member:<deviceId>` {name, addressName, gender, color} и
/// `pair` {since}. Всё additive (I8).
library;

import '../sync/replica.dart';
import 'calendar.dart';

/// Drives «добавил / добавила», «зажёг / зажгла».
enum MemberGender { m, f }

class Member {
  final String deviceId;

  /// «Михаил».
  final String name;

  /// How the app greets them: «Миша».
  final String addressName;
  final MemberGender gender;

  /// Author colour token: `michael` or `sofia`.
  final String? color;

  const Member({
    required this.deviceId,
    required this.name,
    required this.addressName,
    required this.gender,
    this.color,
  });

  static Member? fromFields(String deviceId, Map<String, String> f) {
    final name = f['name'];
    if (name == null || name.isEmpty) return null;
    final address = f['addressName'];
    return Member(
      deviceId: deviceId,
      name: name,
      addressName: (address == null || address.isEmpty) ? name : address,
      gender: f['gender'] == 'f' ? MemberGender.f : MemberGender.m,
      color: f['color'],
    );
  }

  Map<String, String> toFields() => {
        'name': name,
        'addressName': addressName,
        'gender': gender.name,
        if (color != null) 'color': color!,
      };
}

class ProfileRepo {
  final Replica replica;
  ProfileRepo(this.replica);

  static const _m = 'member:';
  static const _pair = 'pair';

  void upsertMember(Member m) {
    for (final e in m.toFields().entries) {
      replica.set(_m + m.deviceId, e.key, e.value);
    }
  }

  Member? member(String deviceId) {
    final f = replica.entity(_m + deviceId);
    return f == null ? null : Member.fromFields(deviceId, f);
  }

  List<Member> members() => [
        for (final e in replica.view().entries)
          if (e.key.startsWith(_m))
            if (Member.fromFields(e.key.substring(_m.length), e.value)
                case final m?)
              m,
      ];

  /// The other member, once their profile has synced.
  Member? partnerOf(String me) =>
      members().where((m) => m.deviceId != me).firstOrNull;

  void setSince(DateTime d) => replica.set(_pair, 'since',
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');

  /// Relationship start date (local, no time).
  DateTime? since() {
    final s = replica.entity(_pair)?['since'];
    if (s == null) return null;
    final d = DateTime.tryParse(s);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// «1 461 дней вместе»: whole days since the start, or null.
  int? daysTogether(DateTime now) {
    final s = since();
    if (s == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    return (today.difference(s).inHours / 24).round();
  }

  /// Days to the next anniversary (0 on the day), or null.
  int? daysToAnniversary(DateTime now) {
    final s = since();
    if (s == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final next = nextAnniversary(s.month, s.day, today);
    return (next.difference(today).inHours / 24).round();
  }
}
