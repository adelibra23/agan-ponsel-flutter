from pathlib import Path
root=Path(__file__).resolve().parent.parent
checks={
  'pubspec.yaml': ['version: 1.3.0+23', 'google_sign_in:', 'workmanager:', 'flutter_local_notifications:', 'shared_preferences_android: 2.4.28'],
  'lib/main.dart': ['BackgroundJobs.init()', 'AganStartupGate', 'PinGate'],
  'lib/screens/others.dart': ['DriveBackupSettingsScreen', 'DebtAlarmSettingsScreen', 'WhatsappAgentSettingsScreen'],
  'lib/services/backup_service.dart': ['createBackupBytes()', 'sha256', 'databaseVersion'],
  'lib/services/drive_backup_service.dart': ['drive.file', 'uploadType=multipart', 'runIfDue()', 'agan_drive_last_ok'],
  'lib/services/debt_alarm_service.dart': ['!config.enabled', 's.count == 0', 'agan_alarm_last_day', 'r.isPaid'],
  'lib/services/background_jobs.dart': ['@pragma(', 'registerPeriodicTask', 'NetworkType.unmetered'],
  'scripts/prepare_android.py': ['POST_NOTIFICATIONS'],
  '.github/workflows/build-apk.yml': ['test/build23_schedule_test.dart', 'AGAN-PONSEL-v1.3.0-Build23-APK', 'WhatsApp Agent Webhook'],
}
for path,needles in checks.items():
    f=root/path
    assert f.is_file(), f'Missing: {path}'
    data=f.read_text()
    for needle in needles:
        assert needle in data, f'Missing {needle!r} in {path}'
print('OK: Build23 integration, secure Drive scope, overdue guard, CI and startup hotfix present')
