import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/design_system/ms_format.dart';

/// No-break space used between thousands and before ₽.
const nb = ' ';

void main() {
  setUpAll(initMsFormat);

  group('numbers and money', () {
    test('thousands are grouped with a no-break space', () {
      expect(formatNumber(999), '999');
      expect(formatNumber(1461), '1${nb}461');
      expect(formatNumber(84500), '84${nb}500');
      expect(formatNumber(1000000), '1${nb}000${nb}000');
      expect(formatNumber(-1500), '−1${nb}500');
    });

    test('money: «84 500 ₽», quick add «+ 1 000 ₽»', () {
      expect(formatMoney(84500), '84${nb}500$nb₽');
      expect(formatMoney(0), '0$nb₽');
      expect(formatMoneyDelta(1000), '+${nb}1${nb}000$nb₽');
    });
  });

  group('dates and times', () {
    final thursday = DateTime(2026, 10, 8, 21, 14);

    test('«8 октября», «четверг, 8 октября», «чт»', () {
      expect(formatDayMonth(thursday), '8 октября');
      expect(formatWeekdayDayMonth(thursday), 'четверг, 8 октября');
      expect(formatWeekdayShort(thursday), 'чт');
      expect(formatWeekdayShort(DateTime(2026, 10, 9)), 'пт');
    });

    test('month title is capitalised nominative: «Октябрь»', () {
      expect(formatMonthTitle(thursday), 'Октябрь');
      expect(formatMonthTitle(DateTime(2026, 3, 1)), 'Март');
    });

    test('time «21:14», morning without a leading zero «8:12»', () {
      expect(formatTime(thursday), '21:14');
      expect(formatTime(DateTime(2026, 10, 8, 8, 12)), '8:12');
    });
  });

  group('plurals and relative days', () {
    test('ruPlural: день / дня / дней', () {
      String d(int n) => ruPlural(n, 'день', 'дня', 'дней');
      expect([1, 2, 5, 11, 21, 22, 54, 112, 129].map(d).toList(), [
        'день', 'дня', 'дней', 'дней', 'день', 'дня', 'дня', 'дней', 'дней',
      ]);
    });

    test('inDays: «сегодня», «завтра», «через 54 дня»', () {
      expect(inDays(0), 'сегодня');
      expect(inDays(1), 'завтра');
      expect(inDays(11), 'через 11 дней');
      expect(inDays(54), 'через 54 дня');
      expect(inDays(129), 'через 129 дней');
    });

    test('ago: «только что», «2 мин назад», «3 ч назад», «вчера», date', () {
      final now = DateTime(2026, 10, 8, 21, 14);
      expect(ago(now.subtract(const Duration(seconds: 30)), now), 'только что');
      expect(ago(now.subtract(const Duration(minutes: 2)), now), '2 мин назад');
      expect(ago(now.subtract(const Duration(hours: 3)), now), '3 ч назад');
      expect(ago(DateTime(2026, 10, 7, 23), now), 'вчера');
      expect(ago(DateTime(2026, 10, 2, 12), now), '2 октября');
    });
  });

  group('gendered verbs', () {
    test('regular, irregular and reflexive past tense', () {
      expect(gendered('добавил', feminine: false), 'добавил');
      expect(gendered('добавил', feminine: true), 'добавила');
      expect(gendered('изменил', feminine: true), 'изменила');
      expect(gendered('зажёг', feminine: true), 'зажгла');
      expect(gendered('внёс', feminine: true), 'внесла');
      expect(gendered('присоединился', feminine: true), 'присоединилась');
    });
  });
}
