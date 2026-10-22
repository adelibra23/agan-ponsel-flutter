import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/drive_backup_service.dart';
import 'package:agan_ponsel/services/debt_alarm_service.dart';

void main() {
  test('daily backup waits until selected local clock time', () {
    const config = DriveBackupConfig(enabled: true, hour: 2, minute: 30);
    final before = DateTime(2026, 10, 22, 2, 29);
    final after = DateTime(2026, 10, 22, 2, 31);
    final last = DateTime(2026, 10, 21, 2, 31);
    expect(config.due(before, last), isFalse);
    expect(config.due(after, last), isTrue);
    expect(config.due(after, DateTime(2026, 10, 22, 2, 30)), isFalse);
  });

  test('weekly backup based on day of week', () {
    const config = DriveBackupConfig(enabled: true,
      frequency: 'weekly', weekday: DateTime.monday, hour: 9);
    expect(config.due(DateTime(2026, 10, 22, 20),
      DateTime(2026, 10, 19, 9, 30)), isFalse);
    expect(config.due(DateTime(2026, 10, 26, 10),
      DateTime(2026, 10, 19, 9, 30)), isTrue);
  });

  test('monthly backup supports safe day 28', () {
    const config = DriveBackupConfig(enabled: true,
      frequency: 'monthly', monthDay: 28, hour: 2);
    expect(config.due(DateTime(2026, 2, 28, 3),
      DateTime(2026, 1, 28, 3)), isTrue);
  });

  test('disabled schedules never run', () {
    const config = DriveBackupConfig(enabled: false);
    expect(config.due(DateTime(2026, 10, 22, 10), null), isFalse);
    const alarm = DebtAlarmConfig(enabled: false);
    expect(alarm.eligibleTime(DateTime(2026, 10, 22, 15)), isFalse);
  });

  test('alarm starts at selected local hour', () {
    const alarm = DebtAlarmConfig(enabled: true, hour: 9, minute: 15);
    expect(alarm.eligibleTime(DateTime(2026, 10, 22, 9, 14)), isFalse);
    expect(alarm.eligibleTime(DateTime(2026, 10, 22, 9, 15)), isTrue);
  });
}
