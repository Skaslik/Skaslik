/// A guided tour of Dart, driven by the real МС core library.
///
/// Story: Misha's and Sofia's phones pair, add loyalty cards while offline,
/// sync through an (end-to-end encrypted) cloud folder, and resolve a
/// conflicting edit. Each step introduces a Dart feature in the comments.
///
/// Run from the `core/` folder:
///   dart run example/dart_tour.dart
library;

import 'dart:typed_data';

import 'package:ms_core/ms_core.dart';

// ─── Lesson 1: classes, interfaces, async ────────────────────────────────────
// Every Dart class is also an interface. `implements BlobStore` promises we
// provide every BlobStore method, and the compiler checks that we did.
// This fake stands in for Yandex.Disk: just a Map from path to bytes.
class FakeCloud implements BlobStore {
  final files = <String, Uint8List>{}; // type inferred: Map<String, Uint8List>

  @override
  Future<bool> ping() async => true; // `async` wraps the result in a Future

  @override
  Future<void> upload({required String path, required List<int> bytes}) async {
    files[path] = Uint8List.fromList(bytes);
  }

  @override
  Future<List<int>> download(String path) async {
    final f = files[path]; // a Map lookup returns `Uint8List?` (may be null)
    if (f == null) throw YandexDiskError(YandexDiskErrorCode.notFound, path);
    return f; // after the null check Dart "promotes" f to non-null Uint8List
  }

  @override
  Future<void> ensureDir(String path) async {}
}

// ─── Lesson 2: fields, constructors, `late` ──────────────────────────────────
class Phone {
  // A private named constructor (leading `_` = private to this file).
  // `this.owner` assigns the parameter straight into the field.
  Phone._(this.owner, this.keys, this.deviceId, this.replica);

  final String owner; // `final`: set once, never reassigned
  final DevicePairing keys;
  final String deviceId;
  final Replica replica; // the CRDT: this phone's copy of the data

  // `late` + initializer: computed lazily on first access.
  late final CardsRepo cards = CardsRepo(replica);

  // `late` without initializer: "I promise to set this before reading it".
  // Reading it too early throws a LateInitializationError at runtime.
  late DiskSync sync;

  // Constructors can't be async, so a static async method builds the object.
  static Future<Phone> create(String owner, ClockFn clock) async {
    final keys = await createDevicePairing(); // X25519 key pair
    final id = deviceIdForPub(keys.pub.bytes);
    return Phone._(owner, keys, id, Replica(id, clock: clock));
  }
}

// ─── Lesson 3: switch expressions are exhaustive ─────────────────────────────
// Remove one case and this won't compile: Dart checks that every enum value
// is handled. `=>` is shorthand for a function whose body is one expression.
String label(CardCategory c) => switch (c) {
      CardCategory.supermarket => 'groceries',
      CardCategory.pharmacy => 'pharmacy',
      CardCategory.fuel => 'fuel',
      CardCategory.cafe => 'coffee',
      CardCategory.other => 'other',
    };

void section(String title) => print('\n== $title ${'=' * (66 - title.length)}');

void showCards(Phone p) {
  print("${p.owner}'s phone:");
  for (final c in p.cards.all()) {
    final star = c.favorite ? '*' : ' ';
    // `??` gives a fallback when the left side is null.
    print('  $star ${c.merchantName.padRight(12)} ${label(c.category).padRight(10)}'
        ' ${c.barcodeValue.padRight(14)} note: ${c.note ?? '-'}');
  }
}

/// One full sync round: each phone uploads its snapshot, then downloads the
/// other's and merges it.
Future<void> syncBoth(Phone a, Phone b) async {
  await a.sync.publish(a.replica);
  await b.sync.publish(b.replica);
  await a.sync.fetch(a.replica);
  await b.sync.fetch(b.replica);
}

String fingerprint(Phone p) =>
    p.cards.all().map((c) => '${c.id}:${c.merchantName}:${c.note}').join('|');

// `main` is the entry point. It returns a Future because it awaits things.
Future<void> main() async {
  // ─── Lesson 4: closures ───────────────────────────────────────────────────
  // `clock` captures the variable `now`. Moving `now` forward moves time for
  // both phones, so we control who wrote last.
  var now = 1700000000000;
  int clock() => now;

  section('1. Each phone creates its own key pair');
  final misha = await Phone.create('Misha', clock);
  final sofia = await Phone.create('Sofia', clock);
  print('Misha device id: ${misha.deviceId}');
  print('Sofia device id: ${sofia.deviceId}');

  section('2. Pairing: both sides derive the SAME family key');
  const familySecret = 'sun rise moon night'; // `const`: known at compile time
  // ─── Lesson 5: records ────────────────────────────────────────────────────
  // `(x, y)` is a record, an anonymous fixed-size tuple, and
  // `final (a, b) = ...` destructures it.
  // pair() uses Argon2id, which is deliberately slow (~1-2s each).
  final (forMisha, forSofia) = (
    await pair(misha.keys, sofia.keys.pub, familySecret),
    await pair(sofia.keys, misha.keys.pub, familySecret),
  );
  final same = bytesToHex(forMisha.master) == bytesToHex(forSofia.master);
  print('Misha master: ${shortHex(forMisha.master)}');
  print('Sofia master: ${shortHex(forSofia.master)}');
  print('Identical? $same (X25519 is symmetric, so neither side sent a key)');

  final cloud = FakeCloud();
  // Records also work as patterns in a for-loop.
  for (final (me, peer, result) in [
    (misha, sofia, forMisha),
    (sofia, misha, forSofia),
  ]) {
    me.sync = DiskSync(
      store: cloud,
      syncKey: await syncKeyFromMaster(result.master),
      familyId: familyIdFromMaster(result.master),
      deviceId: me.deviceId,
      peerDeviceId: peer.deviceId,
      domain: Domain.cards.name, // every enum value has a `.name` string
    );
  }

  section('3. Offline: each phone adds a loyalty card');
  final barcode = completeEan13('460123456789'); // appends the check digit
  print('EAN-13 with check digit: $barcode  valid=${isValidEan13(barcode)}');
  // ─── Lesson 6: named arguments ────────────────────────────────────────────
  // `required` named args make call sites self-documenting; optional ones
  // (note, cardNumber) can be skipped and default to null.
  misha.cards.upsert(LoyaltyCard(
    id: 'c1',
    merchantName: 'Pyaterochka',
    category: CardCategory.supermarket,
    barcodeType: BarcodeType.ean13,
    barcodeValue: barcode,
    favorite: true,
  ));
  now += 1000;
  sofia.cards.upsert(LoyaltyCard(
    id: 'c2',
    merchantName: 'Coffee Like',
    category: CardCategory.cafe,
    barcodeType: BarcodeType.qr,
    barcodeValue: 'CL-77-0042',
  ));
  showCards(misha);
  showCards(sofia);

  section('4. Sync through the cloud folder');
  await syncBoth(misha, sofia);
  showCards(misha);
  showCards(sofia);

  section('5. What the cloud actually stores');
  // Destructuring a MapEntry by its getters: `:key` means `key: key`.
  for (final MapEntry(:key, :value) in cloud.files.entries) {
    print('$key  ${value.length} bytes  ${shortHex(value, 40)}');
  }
  print('Only ciphertext. Even our own key fails if the domain label is wrong:');
  // ─── Lesson 7: exceptions ─────────────────────────────────────────────────
  try {
    await openSyncBlob(
      syncKey: await syncKeyFromMaster(forMisha.master),
      domain: Domain.messages.name, // the blob was sealed for "cards"
      sealed: cloud.files[misha.sync.ownPath]!, // `!`: "I know it's not null"
    );
    print('  decrypted?! (should not happen)');
  } catch (e) {
    print('  rejected: ${e.runtimeType}');
  }

  section('6. Conflict: both edit the same card note while offline');
  now += 1000;
  misha.replica.set('card:c1', 'note', 'Scan the app, not plastic');
  print('Misha writes at t=$now');
  now += 1000;
  sofia.replica.set('card:c1', 'note', 'Expires in December');
  print('Sofia writes at t=$now (later)');
  await syncBoth(misha, sofia);
  showCards(misha);
  showCards(sofia);
  final converged = fingerprint(misha) == fingerprint(sofia);
  print('Both phones identical? $converged (last writer wins, deterministically)');

  section('7. Delete on one phone, sync, gone on both');
  now += 1000;
  sofia.cards.remove('c2');
  await syncBoth(misha, sofia);
  // Collection-for inside a list literal, then join.
  print('Misha now has: ${[for (final c in misha.cards.all()) c.merchantName].join(', ')}');
  print('Sofia now has: ${[for (final c in sofia.cards.all()) c.merchantName].join(', ')}');
}
