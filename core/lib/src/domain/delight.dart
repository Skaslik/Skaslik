/// «Второй слой» — деликатные фичи: капсулы времени, ритуалы, пульс дня,
/// память мест. Все — маленькие CRDT-доки + чистая логика (без ML, I6).
library;

import 'dart:math' as _math;

import '../sync/replica.dart';

// ---------------------------------------------------------------------------
// Капсула времени: «закрыть до даты», открывается вместе (подтверждение обоих)
// ---------------------------------------------------------------------------

class Capsule {
  final String id;
  final String title;
  final int sealDate; // ms — когда открыть
  final List<String> mediaRefs;
  final String? letter;
  final int? openedAt;
  final List<String> openedBy; // id устройств, подтвердивших открытие
  const Capsule({
    required this.id,
    required this.title,
    required this.sealDate,
    this.mediaRefs = const [],
    this.letter,
    this.openedAt,
    this.openedBy = const [],
  });

  bool get sealed => openedAt == null;
  bool canOpen(DateTime now) =>
      sealed && sealDate <= now.millisecondsSinceEpoch;

  static Capsule? fromFields(String id, Map<String, String> f) {
    final seal = int.tryParse(f['seal'] ?? '');
    if (seal == null) return null;
    return Capsule(
      id: id,
      title: f['title'] ?? id,
      sealDate: seal,
      mediaRefs: f['media']?.split(',').where((s) => s.isNotEmpty).toList() ?? const [],
      letter: f['letter'],
      openedAt: int.tryParse(f['openedAt'] ?? ''),
      openedBy: f['openedBy']?.split(',').where((s) => s.isNotEmpty).toList() ?? const [],
    );
  }

  Map<String, String> toFields() => {
        'title': title,
        'seal': '$sealDate',
        'media': mediaRefs.join(','),
        if (letter != null) 'letter': letter!,
        if (openedAt != null) 'openedAt': '$openedAt',
        'openedBy': openedBy.join(','),
      };
}

class CapsulesRepo {
  final Replica replica;
  CapsulesRepo(this.replica);
  static const _p = 'capsule:';

  void seal(Capsule c) {
    for (final entry in c.toFields().entries) {
      replica.set(_p + c.id, entry.key, entry.value);
    }
  }

  /// Подтвердить открытие с устройства [deviceId]. Открывается, когда оба
  /// устройства подтвердили (или по дате — для «мягкого» режима).
  void confirmOpen(String id, String deviceId, int at) {
    final f = replica.entity(_p + id);
    if (f == null) return;
    final c = Capsule.fromFields(id, f)!;
    if (!c.openedBy.contains(deviceId)) {
      replica.set(_p + id, 'openedBy',
          [...c.openedBy, deviceId].join(','));
      if (c.openedAt == null) {
        replica.set(_p + id, 'openedAt', '$at');
      }
    }
  }

  Capsule? get(String id) {
    final f = replica.entity(_p + id);
    return f == null ? null : Capsule.fromFields(id, f);
  }

  List<Capsule> all() {
    final out = <Capsule>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final c = Capsule.fromFields(e.key.substring(_p.length), e.value);
      if (c != null) out.add(c);
    }
    out.sort((a, b) => a.sealDate.compareTo(b.sealDate));
    return out;
  }
}

// ---------------------------------------------------------------------------
// Ритуалы: «я думал о тебе» — точка; маячок тишины
// ---------------------------------------------------------------------------

enum RitualKind { dot, beacon }

class Ritual {
  final String id;
  final String from;
  final RitualKind kind;
  final int at;
  const Ritual({required this.id, required this.from, required this.kind, required this.at});

  static Ritual? fromFields(String id, Map<String, String> f) {
    final at = int.tryParse(f['at'] ?? '');
    if (at == null) return null;
    return Ritual(
      id: id,
      from: f['from'] ?? '',
      kind: f['kind'] == 'beacon' ? RitualKind.beacon : RitualKind.dot,
      at: at,
    );
  }

  Map<String, String> toFields() => {
        'from': from,
        'kind': kind.name,
        'at': '$at',
      };
}

class RitualsRepo {
  final Replica replica;
  RitualsRepo(this.replica);
  static const _p = 'ritual:';

  void send(Ritual r) {
    for (final entry in r.toFields().entries) {
      replica.set(_p + r.id, entry.key, entry.value);
    }
  }

  /// Ритуалы, не прочитанные этим устройством.
  List<Ritual> unread(String deviceId, DateTime now) {
    final out = <Ritual>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      if (e.value['read:$deviceId'] == '1') continue;
      final r = Ritual.fromFields(e.key.substring(_p.length), e.value);
      if (r != null) out.add(r);
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  void markRead(String id, String deviceId) =>
      replica.set(_p + id, 'read:$deviceId', '1');
}

// ---------------------------------------------------------------------------
// Пульс дня: энергия/усталость/обнимашки — цветные волны
// ---------------------------------------------------------------------------

enum PulseValue { peak, tired, hug }

class Pulse {
  final String id;
  final String by;
  final PulseValue value;
  final int day; // ms start-of-day
  const Pulse({required this.id, required this.by, required this.value, required this.day});

  static Pulse? fromFields(String id, Map<String, String> f) {
    final day = int.tryParse(f['day'] ?? '');
    if (day == null) return null;
    final v = switch (f['v']) {
      'peak' => PulseValue.peak,
      'tired' => PulseValue.tired,
      'hug' => PulseValue.hug,
      _ => PulseValue.peak,
    };
    return Pulse(id: id, by: f['by'] ?? '', value: v, day: day);
  }

  Map<String, String> toFields() => {
        'by': by,
        'v': value.name,
        'day': '$day',
      };
}

class PulseRepo {
  final Replica replica;
  PulseRepo(this.replica);
  static const _p = 'pulse:';

  void send(Pulse p) {
    for (final entry in p.toFields().entries) {
      replica.set(_p + p.id, entry.key, entry.value);
    }
  }

  /// Пульс по дням (для «волн»).
  List<Pulse> byDay({DateTime? from, DateTime? to}) {
    final out = <Pulse>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final p = Pulse.fromFields(e.key.substring(_p.length), e.value);
      if (p == null) continue;
      if (from != null && p.day < from.millisecondsSinceEpoch) continue;
      if (to != null && p.day > to.millisecondsSinceEpoch) continue;
      out.add(p);
    }
    out.sort((a, b) => a.day.compareTo(b.day));
    return out;
  }
}

// ---------------------------------------------------------------------------
// Память мест: значимые геоточки
// ---------------------------------------------------------------------------

class Place {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radius; // метры
  final List<String> mediaRefs;
  final String? note;
  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radius = 150,
    this.mediaRefs = const [],
    this.note,
  });

  static Place? fromFields(String id, Map<String, String> f) {
    final lat = double.tryParse(f['lat'] ?? '');
    final lng = double.tryParse(f['lng'] ?? '');
    if (lat == null || lng == null) return null;
    return Place(
      id: id,
      name: f['name'] ?? id,
      lat: lat,
      lng: lng,
      radius: double.tryParse(f['radius'] ?? '') ?? 150,
      mediaRefs: f['media']?.split(',').where((s) => s.isNotEmpty).toList() ?? const [],
      note: f['note'],
    );
  }

  Map<String, String> toFields() => {
        'name': name,
        'lat': lat.toStringAsFixed(6),
        'lng': lng.toStringAsFixed(6),
        'radius': '$radius',
        'media': mediaRefs.join(','),
        if (note != null) 'note': note!,
      };

  /// Примерное расстояние (плоская модель, достаточно для radius-проверок < 5 км).
  double distanceMeters(double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat);
    final dLng = _rad(lng2 - lng);
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
            _cos(_rad(lat)) * _cos(_rad(lat2)) * _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  bool near(double lat2, double lng2) => distanceMeters(lat2, lng2) <= radius;

  static double _rad(double d) => d * 3.141592653589793 / 180.0;
  static double _sin(double x) => _math.sin(x);
  static double _cos(double x) => _math.cos(x);
  static double _sqrt(double x) => _math.sqrt(x);
  static double _atan2(double y, double x) => _math.atan2(y, x);
}


class PlacesRepo {
  final Replica replica;
  PlacesRepo(this.replica);
  static const _p = 'place:';

  void upsert(Place p) {
    for (final entry in p.toFields().entries) {
      replica.set(_p + p.id, entry.key, entry.value);
    }
  }

  Place? get(String id) {
    final f = replica.entity(_p + id);
    return f == null ? null : Place.fromFields(id, f);
  }

  List<Place> all() {
    final out = <Place>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final p = Place.fromFields(e.key.substring(_p.length), e.value);
      if (p != null) out.add(p);
    }
    return out;
  }

  Place? nearest(double lat2, double lng2) {
    Place? best;
    double bestDist = double.infinity;
    for (final pl in all()) {
      final d = pl.distanceMeters(lat2, lng2);
      if (d < bestDist) {
        best = pl;
        bestDist = d;
      }
    }
    return best;
  }
}
