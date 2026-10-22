"""Non-destructive Build 23 overlay, intended for Build22 GitHub repository.
Run AFTER extracting ZIP from the root of the existing AGAN PONSEL project.
The script patches current files instead of replacing recent AGANA WhatsApp source.
"""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
pub = root / 'pubspec.yaml'
wf = root / '.github/workflows/build-apk.yml'
main = root / 'lib/main.dart'
others = root / 'lib/screens/others.dart'
android = root / 'scripts/prepare_android.py'
readme = root / 'README.md'
changelog = root / 'CHANGELOG.md'

for source in [pub,wf,main,others,android]:
    assert source.is_file(), f'Tidak ada file proyek: {source}'
assert (root / 'lib/screens/settings/whatsapp_agent_settings.dart').is_file(), 'Build21 WhatsApp belum ada'
assert (root / 'lib/services/receivables_service.dart').is_file(), 'Source piutang tidak ada'
assert (root / 'lib/services/debt_alarm_service.dart').is_file(), 'File fitur Build23 belum diekstrak'
assert 'version: 11' in (root / 'lib/core/database.dart').read_text(), 'Perlu SQLite Build22 v11'

s = pub.read_text()
assert 'shared_preferences_android: 2.4.28' in s, 'Hotfix startup Build20 tidak boleh hilang'
assert 'version: 1.2.0+22' in s or 'version: 1.3.0+23' in s, 'Gunakan source Build22 sebelum patch'
s = s.replace('version: 1.2.0+22','version: 1.3.0+23',1)
for dep in [
    '  google_sign_in: ^7.2.0',
    '  workmanager: ^0.10.10',
    '  flutter_local_notifications: ^20.1.0',
]:
    if dep not in s:
        key = '  shared_preferences: ^2.5.3'
        assert key in s, 'dependencies pubspec berubah'
        s = s.replace(key, key+'\n'+dep, 1)

s_main = main.read_text()
if "import 'services/background_jobs.dart';" not in s_main:
    key = "import 'core/database.dart';"
    assert key in s_main
    s_main = s_main.replace(key, key+"\nimport 'services/background_jobs.dart';",1)
if 'BackgroundJobs.init().catchError' not in s_main:
    key = "initialTemplate: prefs.getString('app_template_style') ?? 'Biru Orbit'));"
    assert key in s_main, 'main() berubah, perlu review manual'
    s_main = s_main.replace(key,key+"\n    // Scheduling must never block login/PIN or crash startup on failure.\n    BackgroundJobs.init().catchError((Object _) {});",1)

s_others = others.read_text()
for imp in [
    "import 'settings/drive_backup_settings.dart';",
    "import 'settings/debt_alarm_settings.dart';",
]:
    if imp not in s_others:
        key = "import 'settings/settings_pages.dart';"
        assert key in s_others
        s_others = s_others.replace(key,key+'\n'+imp,1)
if "title: 'Google Drive Otomatis'" not in s_others:
    target = "      _MenuItem(icon: Icons.backup_rounded, color: const Color(0xFF8054CB),"
    assert target in s_others
    inject = """      _MenuItem(icon: Icons.cloud_upload_rounded, color: const Color(0xFF1677D8),
        title: 'Google Drive Otomatis', subtitle: 'Jadwal backup cloud dan riwayat upload',
        onTap: () => open(const DriveBackupSettingsScreen())),
      _MenuItem(icon: Icons.notifications_active_outlined, color: const Color(0xFFDF7D22),
        title: 'Alarm Jatuh Tempo', subtitle: 'Atur jam, suara dan hari pengingat piutang',
        onTap: () => open(const DebtAlarmSettingsScreen())),
"""
    s_others = s_others.replace(target, inject+target,1)
if "title: 'Alarm Jatuh Tempo'" not in s_others:
    raise AssertionError('Menu alarm tidak dibuat')
# Settings page in others.dart also gets quick links.
if "title: 'Jadwal Backup Google Drive'" not in s_others:
    target="      SettingsCard(icon: Icons.backup_outlined, color: const Color(0xFF8751D1),"
    assert target in s_others
    inject="""      SettingsCard(icon: Icons.cloud_upload_rounded, color: const Color(0xFF1F77C6),
        title: 'Jadwal Backup Google Drive', subtitle: 'Cadangan otomatis lewat akun Google',
        onTap: () => go(const DriveBackupSettingsScreen())),
      SettingsCard(icon: Icons.alarm_rounded, color: const Color(0xFFDE8A24),
        title: 'Alarm Piutang', subtitle: 'Notifikasi jatuh tempo dan tagihan terlambat',
        onTap: () => go(const DebtAlarmSettingsScreen())),
"""
    s_others=s_others.replace(target, inject+target,1)

s_android=android.read_text()
for entry in [
  '''    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',''',
  '''    '<uses-permission android:name="android.permission.WAKE_LOCK" />',''',
]:
    if entry not in s_android:
        target='''    '<uses-permission android:name="android.permission.INTERNET" />','''
        assert target in s_android
        s_android=s_android.replace(target,target+'\n'+entry,1)

# Android minSdk is already set to 24. Add the desugaring required by
# flutter_local_notifications 20.x to BOTH modern Kotlin and legacy Groovy.
if '# BUILD23_NOTIFICATION_DESUGARING' not in s_android:
    s_android += r"""

# BUILD23_NOTIFICATION_DESUGARING: flutter_local_notifications 20 requires
# core library desugaring even for immediate (non-exact) notifications.
for filename in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    gradle = Path(filename)
    if not gradle.exists():
        continue
    body = gradle.read_text()
    kotlin = filename.endswith('.kts')
    flag = 'isCoreLibraryDesugaringEnabled = true' if kotlin else 'coreLibraryDesugaringEnabled true'
    if flag not in body:
        import re
        matched = re.search(r'compileOptions\s*\{', body)
        if not matched:
            raise SystemExit(f'compileOptions block missing: {filename}')
        body = body[:matched.end()] + '\n        ' + flag + body[matched.end():]
    if kotlin:
        body = body.replace('compileSdk = flutter.compileSdkVersion','compileSdk = 36')
        dep = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        if dep not in body:
            body += '\ndependencies {\n    ' + dep + '\n}\n'
    else:
        body = body.replace('compileSdkVersion flutter.compileSdkVersion','compileSdkVersion 36')
        dep = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
        if dep not in body:
            body += '\ndependencies {\n    ' + dep + '\n}\n'
    gradle.write_text(body)
print('Android notifications: desugaring + compileSdk >=35 configured')
"""

s_wf=wf.read_text()
assert 'WhatsApp Agent Webhook' in s_wf, 'Workflow WhatsApp Build21 tidak boleh hilang'
assert 'Smoke test v11 payment edits' in s_wf, 'Workflow Build22 belum dijalankan'
assert 'shared_preferences_android' in s_wf, 'Pemeriksaan hotfix startup hilang'
s_wf=s_wf.replace('AGAN-PONSEL-v1.2.0-Build22-APK','AGAN-PONSEL-v1.3.0-Build23-APK',1)
if 'Check Build23 cloud/alarms integration' not in s_wf:
    marker='      - name: Analyze Flutter code'
    assert marker in s_wf
    s_wf=s_wf.replace(marker,'''      - name: Check Build23 cloud/alarms integration
        run: python3 scripts/check_build23.py

'''+marker,1)
if 'test/build23_schedule_test.dart' not in s_wf:
    marker='test/receivable_build22_test.dart'
    assert marker in s_wf
    s_wf=s_wf.replace(marker,marker+' test/build23_schedule_test.dart',1)

for path,content in ((pub,s),(wf,s_wf),(main,s_main),(others,s_others),(android,s_android)):
    path.write_text(content)

section='''

## AGAN PONSEL v1.3.0 Build23 — Google Drive & Alarm Piutang
- OAuth Google (`drive.file`) dengan setup Android + Web Client ID milik pemilik aplikasi.
- Backup JSON SHA-256 yang sama dengan backup manual, diupload ke folder AGAN PONSEL Backups; tidak ada auto-restore.
- Jadwal harian/mingguan/bulanan, jam target, pilihan Wi-Fi saja, retensi 7/14/30 file, cek status berhasil/gagal dan Backup Sekarang.
- WorkManager memeriksa jadwal di background; waktu eksekusi tidak dijamin tepat karena kebijakan Android dan jaringan.
- Alarm ringkasan piutang belum lunas: terlambat, hari H, 1 hari dan 3 hari sebelumnya, maksimal sekali sehari.
- Izin notifikasi Android diminta pengguna; alarm tidak menyimpan data pelanggan di server.
- Database SQLite tetap v11; tidak mengganti atau menghapus data historis.
'''
for path in (readme,changelog):
    if path.exists() and '## AGAN PONSEL v1.3.0 Build23' not in path.read_text():
        path.write_text(path.read_text() + section)
print('Build23 berhasil diterapkan: versi, plugin, navigasi, Android, dan Actions. Build21-22 terjaga.')
