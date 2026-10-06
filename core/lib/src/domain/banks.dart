/// Домен «Копилки» (финансы): вклады, штрафы, прогноз, архив.
///
/// Чистая арифметика, без ML (I6). История — append-only: «отмена» взноса —
/// компенсирующая запись.
library;

import '../sync/replica.dart';

/// Запись истории (append-only).
class BankEntry {
  final String id;
  final String by;
  final int amount;
  final int at; // ms
  final String? note;
  final bool isFine; // штраф
  final String? fineTo; // кому (id)
  const BankEntry({
    required this.id,
    required this.by,
    required this.amount,
    required this.at,
    this.note,
    this.isFine = false,
    this.fineTo,
  });

  static BankEntry? fromFields(String id, Map<String, String> f) {
    final amt = int.tryParse(f['amount'] ?? '');
    final at = int.tryParse(f['at'] ?? '');
    if (amt == null || at == null) return null;
    return BankEntry(
      id: id,
      by: f['by'] ?? '',
      amount: amt,
      at: at,
      note: f['note'],
      isFine: f['fine'] == '1',
      fineTo: f['fineTo'],
    );
  }

  Map<String, String> toFields() => {
        'by': by,
        'amount': '$amount',
        'at': '$at',
        if (note != null) 'note': note!,
        if (isFine) 'fine': '1',
        if (fineTo != null) 'fineTo': fineTo!,
      };
}

/// Копилка (цель).
class PiggyBank {
  final String id;
  final String goalName;
  final String? icon;
  final int targetAmount;
  final int? targetDate; // ms
  final String currency;
  final int createdAt;

  PiggyBank({
    required this.id,
    required this.goalName,
    this.icon,
    required this.targetAmount,
    this.targetDate,
    this.currency = 'RUB',
    required this.createdAt,
  });

  static PiggyBank? fromFields(String id, Map<String, String> f) {
    final target = int.tryParse(f['target'] ?? '');
    final at = int.tryParse(f['createdAt'] ?? '');
    if (target == null || at == null) return null;
    return PiggyBank(
      id: id,
      goalName: f['name'] ?? id,
      icon: f['icon'],
      targetAmount: target,
      targetDate: int.tryParse(f['targetDate'] ?? ''),
      currency: f['currency'] ?? 'RUB',
      createdAt: at,
    );
  }

  Map<String, String> toFields() => {
        'name': goalName,
        if (icon != null) 'icon': icon!,
        'target': '$targetAmount',
        if (targetDate != null) 'targetDate': '$targetDate',
        'currency': currency,
        'createdAt': '$createdAt',
      };
}

/// Агрегированное состояние копилки.
class BankState {
  final PiggyBank bank;
  final int current;
  final Map<String, int> byUser; // id → сумма
  final bool done;
  const BankState({
    required this.bank,
    required this.current,
    required this.byUser,
    required this.done,
  });

  double get progress => bank.targetAmount <= 0
      ? 1.0
      : (current / bank.targetAmount).clamp(0.0, 1.0);
}

/// Репозиторий копилок поверх [Replica].
///
/// Формат id: `bank:<id>` — сущность-копилка; `contrib:<bankId>:<n>` — вклады;
/// `fine:<bankId>:<n>` — штрафы.
class BanksRepo {
  final Replica replica;
  BanksRepo(this.replica);

  static const _bank = 'bank:';
  static const _contrib = 'contrib:';
  static const _fine = 'fine:';

  void createBank(PiggyBank b) {
    for (final entry in b.toFields().entries) {
      replica.set(_bank + b.id, entry.key, entry.value);
    }
  }

  void removeBank(String id) => replica.delete(_bank + id);

  PiggyBank? getBank(String id) {
    final f = replica.entity(_bank + id);
    return f == null ? null : PiggyBank.fromFields(id, f);
  }

  List<PiggyBank> allBanks() {
    final out = <PiggyBank>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_bank)) continue;
      final b = PiggyBank.fromFields(e.key.substring(_bank.length), e.value);
      if (b != null) out.add(b);
    }
    return out;
  }

  BankState state(String bankId) {
    final bank = getBank(bankId)!;
    var current = 0;
    final byUser = <String, int>{};
    // Вклады.
    for (final e in replica.view().entries) {
      if (!e.key.startsWith('$_contrib$bankId:')) continue;
      final entry = BankEntry.fromFields(e.key, e.value);
      if (entry == null || entry.isFine) continue;
      current += entry.amount;
      byUser[entry.by] = (byUser[entry.by] ?? 0) + entry.amount;
    }
    // Штрафы идут в копилку (положительный вклад в цель), но помечаются.
    for (final e in replica.view().entries) {
      if (!e.key.startsWith('$_fine$bankId:')) continue;
      final entry = BankEntry.fromFields(e.key, e.value);
      if (entry == null || !entry.isFine) continue;
      current += entry.amount;
    }
    return BankState(
      bank: bank,
      current: current,
      byUser: byUser,
      done: current >= bank.targetAmount,
    );
  }

  /// Пополнить копилку (вклад).
  void contribute(String bankId, BankEntry e) {
    final id = '$_contrib$bankId:${e.at}';
    for (final entry in e.toFields().entries) {
      replica.set(id, entry.key, entry.value);
    }
  }

  /// Штраф: сумма уходит в копилку [bankId].
  void fine(String bankId, BankEntry e) {
    final id = '$_fine$bankId:${e.at}';
    for (final entry in e.toFields().entries) {
      replica.set(id, entry.key, entry.value);
    }
  }

  List<BankEntry> history(String bankId) {
    final out = <BankEntry>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith('$_contrib$bankId:') &&
          !e.key.startsWith('$_fine$bankId:')) {
        continue;
      }
      final entry = BankEntry.fromFields(e.key, e.value);
      if (entry != null) out.add(entry);
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

/// Детерминированный прогноз (без ML).
class BankForecast {
  final int monthsToGoal;
  final double monthlyNeeded;
  const BankForecast({required this.monthsToGoal, required this.monthlyNeeded});
}

/// Прогноз: по средней скорости взносов за [windowDays] дней.
///
/// [contributions] — суммы взносов, попавших в окно (без таймстампов):
/// скорость = сумма/дней окна. Возвращает `null`, если данных недостаточно
/// или цель уже достигнута.
BankForecast? forecast({
  required int current,
  required int target,
  required List<int> contributions,
  required DateTime now,
  int windowDays = 30,
}) {
  if (target <= current) return null;
  if (contributions.isEmpty) return null;
  final total = contributions.where((c) => c > 0).fold<int>(0, (a, b) => a + b);
  final perDay = total / windowDays;
  if (perDay <= 0) return null;
  final remaining = target - current;
  final days = (remaining / perDay).ceil();
  return BankForecast(
    monthsToGoal: (days / 30).ceil(),
    monthlyNeeded: remaining / (days / 30.0),
  );
}
