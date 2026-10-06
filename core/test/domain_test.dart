/// Тесты доменных модулей «МС» (чистый Dart, без Flutter).
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  group('Календарь: recurrence', () {
    test('monthly: 31 января → 28 февраля (невисокосный)', () {
      final occ = occurrences(
          r: Recurrence.monthly,
          first: DateTime(2025, 1, 31),
          from: DateTime(2025, 1, 1),
          to: DateTime(2025, 3, 31));
      expect(occ.map((d) => '${d.year}-${d.month}-${d.day}'),
          contains('2025-2-28'));
    });

    test('monthly: 31 января → 29 февраля (високосный)', () {
      final occ = occurrences(
          r: Recurrence.monthly,
          first: DateTime(2024, 1, 31),
          from: DateTime(2024, 1, 1),
          to: DateTime(2024, 3, 31));
      expect(occ.map((d) => '${d.year}-${d.month}-${d.day}'),
          contains('2024-2-29'));
    });

    test('yearly: 29 февраля → 28 февраля в невисокосный', () {
      final occ = occurrences(
          r: Recurrence.yearly,
          first: DateTime(2024, 2, 29),
          from: DateTime(2024, 1, 1),
          to: DateTime(2028, 12, 31));
      final years = occ.where((d) => d.month == 2).toList();
      expect(years.any((d) => d.year == 2025 && d.day == 28), true);
    });
    test('weekly: ровно +7 дней', () {
      final occ = occurrences(
          r: Recurrence.weekly,
          first: DateTime(2025, 1, 6),
          from: DateTime(2025, 1, 1),
          to: DateTime(2025, 2, 1));
      expect(occ.length, 4); // 6, 13, 20, 27 янв
    });

    test('none: одно вхождение в интервал', () {
      final occ = occurrences(
          r: Recurrence.none,
          first: DateTime(2025, 6, 15),
          from: DateTime(2025, 6, 1),
          to: DateTime(2025, 6, 30));
      expect(occ.length, 1);
    });

    test('expand: рекуррентное событие раскладывается по дате', () {
      final ev = CalEvent(
          id: 'e',
          title: 'Ужин',
          start: DateTime(2025, 1, 6, 19, 0),
          recurrence: Recurrence.weekly);
      final out = expand([ev], DateTime(2025, 1, 1), DateTime(2025, 1, 31));
      expect(out.length, 4);
    });

    test('reminders: fireTimes упорядочены', () {
      final start = DateTime(2025, 6, 15, 18, 0);
      final times =
          const ReminderRules([1440, 60, 15]).fireTimes(start);
      expect(times.length, 3);
      expect(times.first, start.subtract(const Duration(days: 1)));
      expect(times.last, start.subtract(const Duration(minutes: 15)));
    });

    test('nextAnniversary: следующая годовщина', () {
      final from = DateTime(2025, 3, 10);
      final next = nextAnniversary(12, 25, from);
      expect(next, DateTime(2025, 12, 25));
      final next2 = nextAnniversary(1, 15, DateTime(2025, 3, 10));
      expect(next2, DateTime(2026, 1, 15));
    });

    test('yearsSince', () {
      expect(yearsSince(DateTime(2000, 5, 1), DateTime(2025, 5, 1)), 25);
      expect(yearsSince(DateTime(2000, 5, 2), DateTime(2025, 5, 1)), 24);
    });
  });

  group('Копилки: арифметика', () {
    Replica replica() => Replica('A');

    test('вклады суммируются, byUser — по участникам', () {
      final rep = replica();
      final repo = BanksRepo(rep);
      repo.createBank(PiggyBank(
          id: 'b1', goalName: 'Отпуск', targetAmount: 100000, createdAt: 1));
      repo.contribute('b1', BankEntry(
          id: 'c1', by: 'michael', amount: 5000, at: 100, note: 'май'));
      repo.contribute('b1', BankEntry(
          id: 'c2', by: 'sofia', amount: 3000, at: 200));
      final st = repo.state('b1');
      expect(st.current, 8000);
      expect(st.byUser['michael'], 5000);
      expect(st.byUser['sofia'], 3000);
      expect(st.progress, closeTo(0.08, 0.001));
    });

    test('fine идёт в копилку', () {
      final rep = replica();
      final repo = BanksRepo(rep);
      repo.createBank(PiggyBank(
          id: 'b1', goalName: 'Цель', targetAmount: 1000, createdAt: 1));
      repo.fine('b1',
          BankEntry(id: 'f1', by: 'michael', amount: 500, at: 100, isFine: true));
      expect(repo.state('b1').current, 500);
    });

    test('done при достижении цели', () {
      final rep = replica();
      final repo = BanksRepo(rep);
      repo.createBank(PiggyBank(
          id: 'b1', goalName: 'Цель', targetAmount: 100, createdAt: 1));
      repo.contribute('b1', BankEntry(id: 'c1', by: 'm', amount: 100, at: 1));
      expect(repo.state('b1').done, true);
    });

    test('forecast: по средней скорости', () {
      final now = DateTime(2025, 6, 15);
      final f = forecast(
        current: 20000,
        target: 100000,
        contributions: [5000, 5000], // 10000 за 30 дней
        now: now,
        windowDays: 30,
      );
      // ~333/день, остаток 80000 → 240 дней → 8 мес.
      expect(f, isNotNull);
      expect(f!.monthsToGoal, inInclusiveRange(7, 9));
    });
  });

  group('Карты: EAN-13', () {
    test('completeEan13 → валидный 13-значный код', () {
      final twelve = '460000000000';
      final full = completeEan13(twelve);
      expect(full.length, 13);
      expect(isValidEan13(full), true);
    });

    test('сдвинутая контрольная → false', () {
      final full = completeEan13('460000000000');
      final wrongDigit = (int.parse(full[12]) + 1) % 10;
      expect(isValidEan13(full.substring(0, 12) + wrongDigit.toString()), false);
    });

    test('completeEan13 добавляет контрольную', () {
      final full = completeEan13('460000000000');
      expect(full.length, 13);
      expect(isValidEan13(full), true);
    });

    test('12 цифр → 13, валидно', () {
      final c = completeEan13('000000000000');
      expect(isValidEan13(c), true);
    });
  });

  group('Сообщения: burn-жизненный цикл', () {
    test('on_view: после просмотра → сгорает', () {
      final rep = Replica('A');
      final repo = MessagesRepo(rep, deviceId: 'local');
      final now = DateTime(2025, 6, 15);
      final at = now.millisecondsSinceEpoch;
      repo.send(Message(
          id: 'm1',
          from: 'sofia',
          kind: MsgKind.text,
          text: 'секрет',
          burn: BurnMode.onView,
          at: at));
      repo.markViewed('m1');
      final due = repo.dueToBurn(now);
      expect(due, contains('m1'));
    });

    test('ttl24h: просроченное → в dueToBurn', () {
      final rep = Replica('A');
      final repo = MessagesRepo(rep, deviceId: 'local');
      final now = DateTime(2025, 6, 15);
      final old = now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      repo.send(Message(
          id: 'm2',
          from: 'michael',
          kind: MsgKind.text,
          text: 'старое',
          burn: BurnMode.ttl24h,
          at: old));
      expect(repo.dueToBurn(now), contains('m2'));
    });

    test('scheduled: скрыто до срока, видимо после', () {
      final rep = Replica('A');
      final repo = MessagesRepo(rep, deviceId: 'local');
      final now = DateTime(2025, 6, 15);
      final sched = now
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      repo.send(Message(
          id: 'm3',
          from: 'sofia',
          kind: MsgKind.text,
          text: 'сюрприз',
          scheduledFor: sched,
          at: now.millisecondsSinceEpoch));
      final before = repo.render(now).firstWhere((v) => v.m.id == 'm3');
      expect(before.revealed, false);
      final after = repo.render(now.add(const Duration(hours: 2)))
          .firstWhere((v) => v.m.id == 'm3');
      expect(after.revealed, true);
    });
  });

  group('Sync engine: оркестрация', () {
    test('flush: доставка по первому доступному контуру', () async {
      final t1 = FakeTransport(available: false);
      final t2 = FakeTransport(available: true);
      final engine = SyncEngine(transports: [t1, t2]);
      engine.enqueue([1, 2, 3]);
      expect(engine.current, SyncStatus.pending);
      final ok = await engine.flush();
      expect(ok, true);
      expect(t2.sent, hasLength(1));
      expect(t1.sent, isEmpty);
      expect(engine.current, SyncStatus.synced);
    });

    test('все контуры недоступны → offline', () async {
      final engine = SyncEngine(transports: [
        FakeTransport(available: false),
      ]);
      engine.enqueue([1]);
      final ok = await engine.flush();
      expect(ok, false);
      expect(engine.current, SyncStatus.offline);
    });

    test('enqueue идемпотентен по содержимому', () async {
      final t = FakeTransport(available: true);
      final engine = SyncEngine(transports: [t]);
      final data = [1, 2, 3];
      engine.enqueue(data);
      engine.enqueue(data); // дубль
      await engine.flush();
      expect(t.sent, hasLength(1));
    });
  });

  group('Безопасность', () {
    test('fake mode: верный пароль открывает, неверный нет', () {
      final fake = FakeMode('decoy123');
      expect(fake.tryUnlock('decoy123'), true);
      expect(fake.tryUnlock('decoy124'), false);
      expect(fake.tryUnlock('short'), false);
    });

    test('two-factor: оба фраза нужны', () {
      final tf = TwoFactorErase(
          phraseA: 'rose', phraseB: 'violet', emergencyCode: 'burn42');
      expect(tf.confirmBoth('rose', 'violet'), true);
      expect(tf.confirmBoth('rose', 'wrong'), false);
      expect(tf.confirmEmergency('burn42'), true);
    });

    test('audit: события фиксируются', () {
      final log = AuditLog();
      log.pair('dev1');
      log.restore('dev1');
      expect(log.all, hasLength(2));
      expect(log.all.last.action, 'restore');
    });
  });

  group('Delight: память мест', () {
    test('haversine: известная дистанция', () {
      final a = Place(id: 'a', name: 'A', lat: 55.75, lng: 37.6);
      // ~111 км на 1 градус широты.
      final b = Place(id: 'b', name: 'B', lat: 56.75, lng: 37.6);
      final d = a.distanceMeters(b.lat, b.lng);
      expect(d, inInclusiveRange(105000, 117000));
    });

    test('near: в пределах radius → true', () {
      final a = Place(id: 'a', name: 'A', lat: 55.75, lng: 37.6, radius: 1000);
      final close = 55.751;
      expect(a.near(close, 37.6), true);
    });
  });
}
