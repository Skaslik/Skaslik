/// Локальные уведомления: напоминания календаря, вехи копилок, «я думал о тебе».
///
/// Использует `flutter_local_notifications`. На S2 — точные будильники
/// (AlarmManager + setAlarmClock для Android 12+), группировка по категориям.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Каноны уведомлений «МС» (группировка по категориям).
class MsNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    // Инициализация таймзоны (для точных zoned-алармов календаря).
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    // Каналы-категории (группировка).
    const calendarChannel = AndroidNotificationChannel(
      'calendar',
      'Календарь',
      description: 'События и напоминания',
      importance: Importance.high,
    );
    const banksChannel = AndroidNotificationChannel(
      'banks',
      'Копилки',
      description: 'Вехи накоплений',
      importance: Importance.defaultImportance,
    );
    const ritualChannel = AndroidNotificationChannel(
      'ritual',
      'МС',
      description: 'Ритуалы пары',
      importance: Importance.defaultImportance,
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(calendarChannel);
    await androidImpl?.createNotificationChannel(banksChannel);
    await androidImpl?.createNotificationChannel(ritualChannel);
    _initialized = true;
  }

  static const _calendarDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'calendar',
      'Календарь',
      channelDescription: 'События и напоминания',
      importance: Importance.high,
    ),
  );

  static const _banksDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'banks',
      'Копилки',
      channelDescription: 'Вехи накоплений',
      importance: Importance.defaultImportance,
    ),
  );

  static const _ritualDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'ritual',
      'МС',
      channelDescription: 'Ритуалы пары',
      importance: Importance.defaultImportance,
    ),
  );

  /// Напоминание о событии (точное, с таймзоной).
  static Future<void> calendarReminder(
      {required String id,
      required String title,
      required DateTime when,
      required String body}) async {
    final scheduledDate = tz.TZDateTime(tz.local,
        when.year, when.month, when.day, when.hour, when.minute);
    await _plugin.zonedSchedule(
      id.hashCode.abs(),
      title,
      body,
      scheduledDate,
      _calendarDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Веха копилки (25/50/75/100%).
  static Future<void> bankMilestone(
      {required String id,
      required String goal,
      required int percent}) async {
    await _plugin.show(
        id.hashCode.abs(), 'Копилка «$goal»', 'Цель на $percent% 🎯',
        _banksDetails);
  }

  /// «Я думал о тебе» (ритуал-пинг).
  static Future<void> ritualPing({required String from}) async {
    await _plugin.show(900000 + (from.hashCode.abs() % 1000), 'МС',
        '💗 $from думает о тебе', _ritualDetails);
  }

  /// Запросить разрешение на уведомления (Android 13+). Best-effort.
  static Future<void> requestPermission() async {
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
    } catch (_) {
      // Не критично.
    }
  }

  /// Запланировать все напоминания события (по offset-правилам).
  ///
  /// Только будущие моменты; прошедшие пропускаются. Идемпотентно по id
  /// (повторный вызов перезаписывает аларм).
  static Future<void> scheduleEvent({
    required String id,
    required String title,
    required DateTime start,
    required List<int> offsetsMin,
  }) async {
    final now = DateTime.now();
    for (var i = 0; i < offsetsMin.length; i++) {
      final fire = start.subtract(Duration(minutes: offsetsMin[i]));
      if (fire.isBefore(now)) continue;
      final suffix = switch (offsetsMin[i]) {
        0 => 'сейчас',
        < 60 => 'через ${offsetsMin[i]} мин',
        < 1440 => 'через ${offsetsMin[i] ~/ 60} ч',
        _ => 'через ${offsetsMin[i] ~/ 1440} дн',
      };
      final nid = (id.hashCode.abs() * 10 + i) % 100000;
      final scheduledDate = tz.TZDateTime(tz.local,
          fire.year, fire.month, fire.day, fire.hour, fire.minute);
      await _plugin.zonedSchedule(
        nid,
        title,
        suffix == 'сейчас' ? 'Пора' : 'Напоминание: $suffix',
        scheduledDate,
        _calendarDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Отменить все напоминания события.
  static Future<void> cancelEvent(String id) async {
    for (var i = 0; i < 8; i++) {
      final nid = (id.hashCode.abs() * 10 + i) % 100000;
      _plugin.cancel(nid);
    }
  }
}
