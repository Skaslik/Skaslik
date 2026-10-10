/// Russian formatting for money, dates, times and gendered verbs.
///
/// «84 500 ₽», «8 октября», «четверг, 8 октября», «21:14», «через 11 дней»,
/// «добавил Михаил» / «добавила София». Call [initMsFormat] once at start-up.
library;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Locale for all dates.
const String kMsLocale = 'ru';

/// Thousands separator. A no-break space, as the prototype's
/// `toLocaleString('ru-RU')` renders it, so «84 500 ₽» never wraps.
const String kThousandsSep = ' ';

/// Load the ru date symbols (bundled, no network). Idempotent.
Future<void> initMsFormat() async {
  await initializeDateFormatting(kMsLocale);
  Intl.defaultLocale = kMsLocale;
}

/// «84 500» — whole number with grouped thousands.
String formatNumber(num value) {
  final n = value.round();
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '−' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(kThousandsSep);
    out.write(digits[i]);
  }
  return out.toString();
}

/// «84 500 ₽».
String formatMoney(num value) => '${formatNumber(value)}$kThousandsSep₽';

/// «+ 1 000 ₽» for quick-add buttons.
String formatMoneyDelta(num value) =>
    '${value < 0 ? '−' : '+'}$kThousandsSep${formatMoney(value.abs())}';

/// «8 октября».
String formatDayMonth(DateTime d) => DateFormat('d MMMM', kMsLocale).format(d);

/// «четверг, 8 октября».
String formatWeekdayDayMonth(DateTime d) =>
    DateFormat('EEEE, d MMMM', kMsLocale).format(d);

/// «четверг».
String formatWeekday(DateTime d) => DateFormat('EEEE', kMsLocale).format(d);

/// «чт».
String formatWeekdayShort(DateTime d) => DateFormat('EE', kMsLocale).format(d);

/// «Октябрь» — screen title of a month.
String formatMonthTitle(DateTime d) =>
    _capitalize(DateFormat('LLLL', kMsLocale).format(d));

/// «21:14», «8:12» (no leading zero, as in the prototype).
String formatTime(DateTime d) => DateFormat('H:mm', kMsLocale).format(d);

/// «50 КБ», «0,6 МБ», «1,4 МБ», «2,3 ГБ» — decimal comma, binary units;
/// megabytes from 100 КБ, as the prototype writes «0,6 МБ».
String formatBytes(int bytes) {
  const k = 1024;
  if (bytes < k) return '$bytes$kThousandsSepБ';
  if (bytes < 100 * k) return '${(bytes / k).round()}$kThousandsSepКБ';
  String one(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  if (bytes < k * k * k) return '${one(bytes / (k * k))}$kThousandsSepМБ';
  return '${one(bytes / (k * k * k))}$kThousandsSepГБ';
}

/// «2,3 из 10 ГБ» — used of total, in gigabytes (or megabytes when small).
String formatDiskUsage(int used, int total) {
  const gb = 1024 * 1024 * 1024, mb = 1024 * 1024;
  final unit = total >= gb ? gb : mb;
  final word = total >= gb ? 'ГБ' : 'МБ';
  String n(double v) => v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1).replaceAll('.', ',');
  return '${n(used / unit)} из ${n(total / unit)}$kThousandsSep$word';
}

/// When a file was added: «сегодня», «вчера», «2 окт», «март 2025».
String formatWhen(DateTime then, DateTime now) {
  if (_sameDay(then, now)) return 'сегодня';
  if (_sameDay(then, DateTime(now.year, now.month, now.day - 1))) {
    return 'вчера';
  }
  if (then.year == now.year) {
    return DateFormat('d MMM', kMsLocale).format(then).replaceAll('.', '');
  }
  return DateFormat('LLLL y', kMsLocale).format(then);
}

/// «1 декабря 2026».
String formatFullDate(DateTime d) =>
    DateFormat('d MMMM y', kMsLocale).format(d);

/// Russian plural: 1 день / 2 дня / 5 дней (one / few / many).
String ruPlural(int n, String one, String few, String many) {
  final a = n.abs();
  final mod10 = a % 10, mod100 = a % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// «N дней» with the right plural.
String daysWord(int n) =>
    '${formatNumber(n)} ${ruPlural(n, 'день', 'дня', 'дней')}';

/// «сегодня», «завтра», «через 11 дней».
String inDays(int days) {
  if (days == 0) return 'сегодня';
  if (days == 1) return 'завтра';
  return 'через ${daysWord(days)}';
}

/// Short past time for meta lines: «только что», «2 мин назад», «3 ч назад»,
/// «вчера», otherwise «8 октября».
String ago(DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (_sameDay(then, now)) return '${diff.inHours} ч назад';
  if (_sameDay(then, DateTime(now.year, now.month, now.day - 1))) {
    return 'вчера';
  }
  return formatDayMonth(then);
}

/// Past-tense verbs whose feminine form is not «masculine + а».
const Map<String, String> _irregularFeminine = {
  'зажёг': 'зажгла',
  'внёс': 'внесла',
  'принёс': 'принесла',
  'испёк': 'испекла',
  'смог': 'смогла',
};

/// Agree a past-tense verb with the member's gender:
/// `gendered('добавил', feminine: true)` → «добавила»,
/// `gendered('зажёг', feminine: true)` → «зажгла»,
/// `gendered('присоединился', feminine: true)` → «присоединилась».
String gendered(String masculine, {required bool feminine}) {
  if (!feminine) return masculine;
  final irregular = _irregularFeminine[masculine];
  if (irregular != null) return irregular;
  if (masculine.endsWith('ся')) {
    return '${masculine.substring(0, masculine.length - 2)}ась';
  }
  return '$masculineа';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
