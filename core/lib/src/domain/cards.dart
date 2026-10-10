/// Домен «Карты лояльности»: штрихкоды, справочник, модели.
///
/// Детерминированные алгоритмы: валидация контрольной суммы EAN-13,
/// генерация. Без ML (I6): сканирование штрихкодов — нативный декодер (ML Kit),
/// здесь — только чистые проверки/кодек.
library;

import '../sync/replica.dart';

/// Тип штрихкода.
enum BarcodeType { qr, ean13, code128, pdf417 }

BarcodeType parseBarcodeType(String? s) {
  switch (s) {
    case 'ean13': return BarcodeType.ean13;
    case 'code128': return BarcodeType.code128;
    case 'pdf417': return BarcodeType.pdf417;
    default: return BarcodeType.qr;
  }
}

/// Категория магазина.
enum CardCategory { supermarket, pharmacy, fuel, cafe, other }

CardCategory parseCardCategory(String? s) {
  switch (s) {
    case 'supermarket': return CardCategory.supermarket;
    case 'pharmacy': return CardCategory.pharmacy;
    case 'fuel': return CardCategory.fuel;
    case 'cafe': return CardCategory.cafe;
    default: return CardCategory.other;
  }
}

/// Карту.
class LoyaltyCard {
  final String id;
  final String merchantName;
  final CardCategory category;
  final BarcodeType barcodeType;
  final String barcodeValue;
  final String? cardNumber;
  final String? note;
  final bool favorite;
  final int? lastUsed; // ms

  /// Device that added the card (additive; older cards have none).
  final String? addedBy;

  LoyaltyCard({
    required this.id,
    required this.merchantName,
    required this.category,
    required this.barcodeType,
    required this.barcodeValue,
    this.cardNumber,
    this.note,
    this.favorite = false,
    this.lastUsed,
    this.addedBy,
  });

  static LoyaltyCard? fromFields(String id, Map<String, String> f) {
    final value = f['barcode'];
    if (value == null || value.isEmpty) return null;
    return LoyaltyCard(
      id: id,
      merchantName: f['merchant'] ?? id,
      category: parseCardCategory(f['category']),
      barcodeType: parseBarcodeType(f['type']),
      barcodeValue: value,
      cardNumber: f['cardNumber'],
      note: f['note'],
      favorite: f['favorite'] == '1',
      lastUsed: int.tryParse(f['lastUsed'] ?? ''),
      addedBy: f['addedBy'],
    );
  }

  Map<String, String> toFields() => {
        'merchant': merchantName,
        'category': category.name,
        'type': barcodeType.name,
        'barcode': barcodeValue,
        if (cardNumber != null) 'cardNumber': cardNumber!,
        if (note != null) 'note': note!,
        'favorite': favorite ? '1' : '0',
        if (lastUsed != null) 'lastUsed': '$lastUsed',
        if (addedBy != null) 'addedBy': addedBy!,
      };
}

/// Репозиторий карт поверх [Replica].
class CardsRepo {
  final Replica replica;
  CardsRepo(this.replica);

  static const _p = 'card:';

  void upsert(LoyaltyCard c) {
    for (final entry in c.toFields().entries) {
      replica.set(_p + c.id, entry.key, entry.value);
    }
  }

  void remove(String id) => replica.delete(_p + id);

  LoyaltyCard? get(String id) {
    final f = replica.entity(_p + id);
    return f == null ? null : LoyaltyCard.fromFields(id, f);
  }

  List<LoyaltyCard> all() {
    final out = <LoyaltyCard>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final c = LoyaltyCard.fromFields(e.key.substring(_p.length), e.value);
      if (c != null) out.add(c);
    }
    // Избранные — первыми, затем по имени.
    out.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return a.merchantName.toLowerCase().compareTo(b.merchantName.toLowerCase());
    });
    return out;
  }

  List<LoyaltyCard> favorites() => all().where((c) => c.favorite).toList();

  void touch(String id, int at) {
    replica.set(_p + id, 'lastUsed', '$at');
  }
}

/// Валидация контрольной суммы EAN-13.
/// Формат: 12 цифр + контрольная. Возвращает `true`, если [code] — корректный
/// EAN-13 (13 цифр, контрольная совпадает).
bool isValidEan13(String code) {
  if (code.length != 13) return false;
  for (final c in code.codeUnits) {
    if (c < 48 || c > 57) return false;
  }
  final check = ean13CheckDigit(code.substring(0, 12));
  return int.parse(code[12]) == check;
}

/// Контрольная цифра EAN-13 для первых 12 цифр.
int ean13CheckDigit(String twelve) {
  if (twelve.length != 12) throw ArgumentError('EAN-13: нужно 12 цифр');
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final d = int.parse(twelve[i]);
    sum += (i.isOdd ? 3 : 1) * d;
  }
  return (10 - (sum % 10)) % 10;
}

/// Добавить/исправить контрольную цифру EAN-13 (для ручного ввода 12 цифр).
String completeEan13(String twelve) {
  if (twelve.length != 12) {
    throw ArgumentError('EAN-13: нужно 12 цифр, получено ${twelve.length}');
  }
  return twelve + ean13CheckDigit(twelve).toString();
}

/// Мини-справочник известных кодов (code → merchant). Встроенный, расширяемый.
/// Детерминированный поиск по префиксу/полному совпадению.
class MerchantDirectory {
  final Map<String, String> _byCode;
  const MerchantDirectory(this._byCode);

  static const MerchantDirectory builtIn = MerchantDirectory({
    // Примеры структуры; наполняется в S5 по данным пользователя.
  });

  String? lookup(String code) => _byCode[code];

  String? lookupPrefix(String prefix) {
    for (final e in _byCode.entries) {
      if (e.key.startsWith(prefix)) return e.value;
    }
    return null;
  }

  Map<String, String> get all => Map.unmodifiable(_byCode);
}
