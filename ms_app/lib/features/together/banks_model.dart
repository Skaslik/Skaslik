/// Piggy-bank wording and arithmetic for «Вместе» (no ML, I6). Pure.
library;

import 'package:ms_core/ms_core.dart';

import '../../core/pair/pair.dart';
import '../../design_system/ms_format.dart';

/// Category key stored in `PiggyBank.icon` → the eyebrow word.
const Map<String, String> kBankCategories = {
  'trip': 'поездка',
  'home': 'дом',
  'car': 'машина',
  'tech': 'техника',
  'food': 'ресторан',
  'health': 'здоровье',
  'fines': 'штрафы',
  'other': 'другое',
};

/// Quick contribution on the card (prototype «+ 1 000 ₽»).
const int kQuickAdd = 1000;

/// Preset amounts in the bank sheet.
const List<int> kAmountPresets = [500, 1000, 5000];

String bankCategory(PiggyBank b) => kBankCategories[b.icon] ?? 'копилка';

/// Shares of a bank: mine, the partner's, and fines.
class BankShares {
  const BankShares({required this.mine, required this.theirs, required this.fines});
  final int mine;
  final int theirs;
  final int fines;
}

BankShares bankShares(List<BankEntry> history, Pair pair) {
  var mine = 0, theirs = 0, fines = 0;
  for (final e in history) {
    if (e.isFine) {
      fines += e.amount;
    } else if (pair.isMine(e.by)) {
      mine += e.amount;
    } else {
      theirs += e.amount;
    }
  }
  return BankShares(mine: mine, theirs: theirs, fines: fines);
}

/// «+5 000 сегодня» when anything was put in today, else null.
String? todayBadge(List<BankEntry> history, DateTime now) {
  final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final sum = history
      .where((e) => !e.isFine && e.at >= start)
      .fold<int>(0, (a, e) => a + e.amount);
  return sum > 0 ? '+${formatNumber(sum)} сегодня' : null;
}

/// Money put in during the last 30 days (the forecast's pace).
int recentPace(List<BankEntry> history, DateTime now) {
  final from = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  return history
      .where((e) => !e.isFine && e.at >= from)
      .fold<int>(0, (a, e) => a + e.amount);
}

/// Forecast line, mono: «к 1 июня успеваем · нужно 16 400 ₽/мес»,
/// «темп 18 000 ₽/мес · цель к марту 2028», «цель собрана».
String bankForecast(BankState st, List<BankEntry> history, DateTime now) {
  final b = st.bank;
  if (st.done) return 'цель собрана';
  final remaining = b.targetAmount - st.current;
  final pace = recentPace(history, now);
  final targetDate = b.targetDate;
  if (targetDate != null) {
    final due = DateTime.fromMillisecondsSinceEpoch(targetDate);
    final days = due.difference(now).inDays;
    if (days <= 0) return 'срок прошёл · осталось ${formatMoney(remaining)}';
    final months = (days / 30).ceil();
    final need = ((remaining / months) / 100).ceil() * 100;
    final ok = pace >= need;
    return 'к ${formatDayMonth(due)} ${ok ? 'успеваем' : 'не успеваем'} · '
        'нужно ${formatMoney(need)}/мес';
  }
  if (pace <= 0) return 'первый взнос — и появится прогноз';
  final f = forecast(
      current: st.current, target: b.targetAmount, contributions: [pace], now: now);
  if (f == null) return 'темп ${formatMoney(pace)}/мес';
  final goal = DateTime(now.year, now.month + f.monthsToGoal);
  return 'темп ${formatMoney(pace)}/мес · цель к ${formatMonthYearDative(goal)}';
}

/// «+500 ₽ · Михаил: не вынес мусор» for the latest fine, or null.
String? lastFineLine(List<BankEntry> history, Pair pair) {
  final fines = history.where((e) => e.isFine).toList();
  if (fines.isEmpty) return null;
  final f = fines.last;
  final who = pair.memberOf(f.by).name;
  final why = (f.note ?? '').trim();
  return '+${formatMoney(f.amount)} · $who${why.isEmpty ? '' : ': $why'}';
}

/// History line in the bank sheet: «5 000 ₽ · добавил Михаил · вчера».
String historyLine(BankEntry e, Pair pair, DateTime now) {
  final m = pair.memberOf(e.by);
  final who = pair.isMine(e.by) ? 'ты' : m.name;
  final when = formatWhen(DateTime.fromMillisecondsSinceEpoch(e.at), now);
  if (e.isFine) {
    final why = (e.note ?? '').trim();
    return '${formatMoney(e.amount)} · штраф · ${m.name}${why.isEmpty ? '' : ': $why'} · $when';
  }
  final note = (e.note ?? '').trim();
  return '${formatMoney(e.amount)} · ${m.verb('внёс')} $who'
      '${note.isEmpty ? '' : ' · $note'} · $when';
}
