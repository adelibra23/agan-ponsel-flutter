import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'debt_alarm_service.dart';
import 'drive_backup_service.dart';

@pragma('vm:entry-point')
void aganBackgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      if (task == BackgroundJobs.driveTask) {
        await DriveBackupService.runIfDue();
      } else if (task == BackgroundJobs.alarmTask) {
        await DebtAlarmService.checkAndNotify();
      }
    } catch (_) {
      // DriveBackupService stores actionable errors locally; failure must not
      // crash the background Flutter isolate. WorkManager retries on next poll.
    }
    return true;
  });
}

class BackgroundJobs {
  BackgroundJobs._();
  static const driveTask = 'agan_drive_backup_poll';
  static const alarmTask = 'agan_debt_alarm_poll';
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      await Workmanager().initialize(aganBackgroundDispatcher);
      _initialized = true;
    }
    await reschedule();
  }

  static Duration _delayToTime(int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    return target.difference(now);
  }

  static Future<void> reschedule() async {
    final work = Workmanager();
    final drive = await DriveBackupConfig.load();
    await work.cancelByUniqueName(driveTask);
    if (drive.enabled) {
      await work.registerPeriodicTask(driveTask, driveTask,
        frequency: const Duration(hours: 1),
        initialDelay: _delayToTime(drive.hour, drive.minute),
        constraints: Constraints(networkType: drive.wifiOnly
          ? NetworkType.unmetered : NetworkType.connected));
    }
    final alarm = await DebtAlarmConfig.load();
    await work.cancelByUniqueName(alarmTask);
    if (alarm.enabled) {
      await work.registerPeriodicTask(alarmTask, alarmTask,
        frequency: const Duration(hours: 1),
        initialDelay: _delayToTime(alarm.hour, alarm.minute));
    }
  }
}
