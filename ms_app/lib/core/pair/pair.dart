/// Who is who on this device: names, addressing, gender and colour of the
/// two partners, plus their device ids.
///
/// Decision #13 defaults: «ты», names Миша / Соня. Until the synced profile
/// domain arrives (Phase 7) «me» is inferred from the colour picked at
/// onboarding (Софии цвет → me = София, otherwise Михаил).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:ms_core/ms_core.dart';

import '../../design_system/ms_format.dart';
import '../../design_system/ms_tokens.dart';
import '../../design_system/widgets/ms_author.dart';
import '../family/family.dart';
import '../providers.dart';

/// Author id the pre-redesign screens wrote instead of a device id. Such
/// entries are treated as mine.
const String kLegacyLocalAuthor = 'local';

@immutable
class PairMember {
  const PairMember({
    required this.author,
    required this.name,
    required this.addressName,
    required this.addressGenitive,
    required this.nameGenitive,
    required this.feminine,
  });

  final MsAuthor author;

  /// «Михаил», «София».
  final String name;

  /// How the app greets them: «Миша», «Соня».
  final String addressName;

  /// «у Миши», «у Сони».
  final String addressGenitive;

  /// «у Михаила», «у Софии».
  final String nameGenitive;
  final bool feminine;

  /// Past-tense verb agreed with this member: «добавил» → «добавила».
  String verb(String masculine) => gendered(masculine, feminine: feminine);

  /// Signature initial on the wall note: «С.».
  String get initial => '${name.characters.first}.';

  /// From a synced profile member.
  factory PairMember.fromMember(Member m, MsAuthor author) {
    final f = m.gender == MemberGender.f;
    return PairMember(
      author: author,
      name: m.name,
      addressName: m.addressName,
      addressGenitive: genitiveName(m.addressName, feminine: f),
      nameGenitive: genitiveName(m.name, feminine: f),
      feminine: f,
    );
  }
}

const PairMember kMichael = PairMember(
    author: MsAuthor.michael,
    name: 'Михаил',
    addressName: 'Миша',
    addressGenitive: 'Миши',
    nameGenitive: 'Михаила',
    feminine: false);

const PairMember kSofia = PairMember(
    author: MsAuthor.sofia,
    name: 'София',
    addressName: 'Соня',
    addressGenitive: 'Сони',
    nameGenitive: 'Софии',
    feminine: true);

@immutable
class Pair {
  const Pair({
    required this.me,
    required this.partner,
    required this.myDeviceId,
    this.partnerDeviceId,
  });

  final PairMember me;
  final PairMember partner;
  final String myDeviceId;

  /// Known once pairing is complete.
  final String? partnerDeviceId;

  /// True for entries written on this device (including legacy `local`).
  bool isMine(String? deviceId) =>
      deviceId == null ||
      deviceId == myDeviceId ||
      deviceId == kLegacyLocalAuthor;

  PairMember memberOf(String? deviceId) => isMine(deviceId) ? me : partner;

  /// Before the profile has anything: «me» from the onboarding colour.
  static Pair fromFamily(Family f) => resolve(f, null);

  /// From the synced profile (Phase 7); whatever is missing falls back to
  /// the onboarding colour and the decision #13 defaults.
  static Pair resolve(Family f, ProfileRepo? profile) {
    final myId = f.deviceId ?? kLegacyLocalAuthor;
    final peer = f.peerPubBytes;
    final peerId = peer == null ? null : deviceIdForPub(peer);
    final mine = profile?.member(myId);
    final theirs = peerId != null
        ? profile?.member(peerId) ?? profile?.partnerOf(myId)
        : profile?.partnerOf(myId);

    final iAmSofia = mine?.color != null
        ? mine!.color == 'sofia'
        : f.color?.toARGB32() == MsPalette.day.sofia.toARGB32();
    final myAuthor = iAmSofia ? MsAuthor.sofia : MsAuthor.michael;
    // Two people, two colours: the partner always gets the other one.
    final partnerAuthor = iAmSofia ? MsAuthor.michael : MsAuthor.sofia;
    final myDefault = iAmSofia ? kSofia : kMichael;
    final partnerDefault = iAmSofia ? kMichael : kSofia;

    return Pair(
      me: mine == null ? myDefault : PairMember.fromMember(mine, myAuthor),
      partner: theirs == null
          ? partnerDefault
          : PairMember.fromMember(theirs, partnerAuthor),
      myDeviceId: myId,
      partnerDeviceId: peerId ?? theirs?.deviceId,
    );
  }
}

final pairProvider = Provider<Pair>((ref) => Pair.resolve(
      ref.watch(familyProvider),
      ProfileRepo(ref.watch(profileProvider).replica),
    ));

/// Genitive of a Russian first name: «Соня» → «Сони», «Миша» → «Миши»,
/// «София» → «Софии», «Михаил» → «Михаила», «Игорь» → «Игоря».
/// Good enough for the couple's names; anything odd is left as is.
String genitiveName(String name, {required bool feminine}) {
  if (name.isEmpty) return name;
  final last = name[name.length - 1];
  final stem = name.substring(0, name.length - 1);
  const hush = 'гкхжшщч';
  final beforeLast = name.length > 1 ? name[name.length - 2] : '';
  switch (last) {
    case 'я':
      return '$stemи';
    case 'а':
      return hush.contains(beforeLast) ? '$stemи' : '$stemы';
    case 'й':
      return '$stemя';
    case 'ь':
      return feminine ? '$stemи' : '$stemя';
  }
  if (feminine) return name; // «Мириам», «Любовь» etc. — unchanged
  return '$nameа';
}
