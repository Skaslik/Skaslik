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

  static Pair fromFamily(Family f) {
    final iAmSofia = f.color?.toARGB32() == MsPalette.day.sofia.toARGB32();
    final peer = f.peerPubBytes;
    return Pair(
      me: iAmSofia ? kSofia : kMichael,
      partner: iAmSofia ? kMichael : kSofia,
      myDeviceId: f.deviceId ?? kLegacyLocalAuthor,
      partnerDeviceId: peer == null ? null : deviceIdForPub(peer),
    );
  }
}

final pairProvider =
    Provider<Pair>((ref) => Pair.fromFamily(ref.watch(familyProvider)));
