import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'receivables_service.dart';

/// Deliberately uses INEXACT WorkManager polling for due-date notification.
/// Does not request Android's privileged exact-alarm permission.
class DebtAlarmConfig {
  final bool enabled;
  final int hour;
  final int minute;
  final bool threeDays;
  final bool oneDay;
  final bool dueToday;
  final bool overdue;
  const DebtAlarmConfig({this.enabled = false, this.hour = 9,
    this.minute = 0, this.threeDays = true, this.oneDay = true,
    this.dueToday = true, this.overdue = true});

  static Future<DebtAlarmConfig> load() async {
    final p = await SharedPreferences.getInstance();
    return DebtAlarmConfig(
      enabled: p.getBool('agan_alarm_enabled') ?? false,
      hour: p.getInt('agan_alarm_hour') ?? 9,
      minute: p.getInt('agan_alarm_minute') ?? 0,
      threeDays: p.getBool('agan_alarm_3days') ?? true,
      oneDay: p.getBool('agan_alarm_1day') ?? true,
      dueToday: p.getBool('agan_alarm_today') ?? true,
      overdue: p.getBool('agan_alarm_overdue') ?? true,
    );
  }

  Future<void> save() async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw const FormatException('Jam alarm tidak valid');
    }
    final p = await SharedPreferences.getInstance();
    await p.setBool('agan_alarm_enabled', enabled);
    await p.setInt('agan_alarm_hour', hour);
    await p.setInt('agan_alarm_minute', minute);
    await p.setBool('agan_alarm_3days', threeDays);
    await p.setBool('agan_alarm_1day', oneDay);
    await p.setBool('agan_alarm_today', dueToday);
    await p.setBool('agan_alarm_overdue', overdue);
  }

  DateTime targetToday(DateTime now) => DateTime(
    now.year, now.month, now.day, hour, minute);

  bool eligibleTime(DateTime now) => enabled && !now.isBefore(targetToday(now));
}

class DebtAlarmSummary {
  final int today;
  final int tomorrow;
  final int threeDays;
  final int overdue;
  final int amount;
  const DebtAlarmSummary({required this.today, required this.tomorrow,
    required this.threeDays, required this.overdue, required this.amount});
  int get count => today + tomorrow + threeDays + overdue;
}

DebtAlarmSummary summarizeDebts(List<Receivable> rows, DebtAlarmConfig config) {
  var today = 0, tomorrow = 0, three = 0, late = 0, amount = 0;
  for (final r in rows) {
    if (r.isPaid) continue;
    var included = false;
    if (r.daysLeft < 0 && config.overdue) {
      late++; included = true;
    } else if (r.daysLeft == 0 && config.dueToday) {
      today++; included = true;
    } else if (r.daysLeft == 1 && config.oneDay) {
      tomorrow++; included = true;
    } else if (r.daysLeft == 3 && config.threeDays) {
      three++; included = true;
    }
    if (included) amount += r.remaining;
  }
  return DebtAlarmSummary(today: today, tomorrow: tomorrow,
    threeDays: three, overdue: late, amount: amount);
}

class DebtAlarmService {
  DebtAlarmService._();
  static final _notification = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize({bool askPermission = false}) async {
    if (!_initialized) {
      await _notification.initialize(settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      _initialized = true;
    }
    if (askPermission) {
      await _notification.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
  }

  static Future<bool> checkAndNotify({bool force = false}) async {
    final config = await DebtAlarmConfig.load();
    final now = DateTime.now();
    if (!config.enabled || (!force && !config.eligibleTime(now))) return false;
    final p = await SharedPreferences.getInstance();
    final day = '${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    // Reserve the notification date only after SQL has been checked. This
    // prevents repeated reminders when the hourly worker is re-run.
    if (!force && p.getString('agan_alarm_last_day') == day) return false;
    final debts = await ReceivablesService.all();
    final s = summarizeDebts(debts, config);
    if (s.count == 0) {
      if (!force) await p.setString('agan_alarm_last_day', day);
      return false;
    }
    await initialize();
    final bits = <String>[
      if (s.overdue > 0) '${s.overdue} terlambat',
      if (s.today > 0) '${s.today} jatuh tempo hari ini',
      if (s.tomorrow > 0) '${s.tomorrow} besok',
      if (s.threeDays > 0) '${s.threeDays} tiga hari lagi',
    ];
    await _notification.show(
      id: 23001, title: 'AGAN PONSEL • Pengingat piutang',
      body: bits.join(' • '),
      notificationDetails: const NotificationDetails(android: AndroidNotificationDetails(
        'agan_piutang_jatuh_tempo', 'Jatuh Tempo Piutang',
        channelDescription: 'Alarm tagihan pelanggan yang belum lunas',
        importance: Importance.high, priority: Priority.high,
        playSound: true, enableVibration: true,
        )),
      payload: 'open_receivable_reminders',
    );
    if (!force) await p.setString('agan_alarm_last_day', day);
    return true;
  }
}
