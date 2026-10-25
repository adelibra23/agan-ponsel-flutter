#!/usr/bin/env python3
"""Static integration tests for v2.0.0 Build30 (not a Flutter compilation)."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
required = {
  'lib/screens/dashboard.dart': [
    'BUILD30_REMINDERS_PRIVATE', 'StatTile(', 'Ringkasan Hari Ini',
    'BalanceCard(', 'ReceivablesScreen()',
  ],
  'lib/widgets/kit.dart': [
    'BUILD30_DEPTH_TILES', 'class StatTile', 'LinearGradient(',
    'BoxShadow(', 'Semantics(', 'class QuickIcon',
  ],
  'lib/widgets/identity.dart': [
    'BUILD30_MOTION_BOTTOM', 'class AnimatedBottomBar',
    'AnimatedPositioned(', 'AnimatedSwitcher(', 'AnimatedScale(',
    'HapticFeedback.selectionClick()', 'Icons.home_rounded',
  ],
  'lib/main.dart': ['IndexedStack(index: selected', 'AnimatedBottomBar(', 'PinGate('],
  'lib/services/biometric_security.dart': [
    'BUILD30_ANDROID_FACE_PREFERENCE', 'BiometricType.face',
    'faceAvailable', 'facePreferred', 'enableFacePreference',
    'disableFacePreference', 'PinSecurity.enabled',
    'AuthenticationOptions(', 'biometricOnly: true',
  ],
  'lib/screens/security/pin_screens.dart': [
    'BUILD30_PIN_FACE_UI', 'Prioritaskan Scan Wajah Android',
    'facePromptAttempted', 'WidgetsBinding.instance.addPostFrameCallback',
    'PinSecurity.verify(', 'enableFacePreference',
    'disableFacePreference', 'BiometricSecurity.authenticate(',
  ],
  'lib/screens/others.dart': ['ReminderCenterScreen()', 'PinSettingsScreen()',
    "title: 'Alarm Jatuh Tempo'"],
  'pubspec.yaml': ['version: 2.0.0+30', 'local_auth: ^2.3.0',
    'shared_preferences_android: 2.4.28'],
  '.github/workflows/build-apk.yml': [
    'AGAN-PONSEL-v2.0.0-Build30-APK',
    'scripts/check_build30.py', 'scripts/smoke_build30_privacy.py',
    'test/build30_ui_security_test.dart', 'Test WhatsApp Agent Webhook',
  ],
  'scripts/check_build29.py': ['version: 2.0.0+30',
    'AGAN-PONSEL-v2.0.0-Build30-APK'],
}
for name, needles in required.items():
    path = root / name
    assert path.is_file(), f'Missing {name}'
    compact = re.sub(r'\s+', '', path.read_text())
    for need in needles:
        assert re.sub(r'\s+', '', need) in compact, f'{name} missing {need!r}'

dash = (root/'lib/screens/dashboard.dart').read_text()
assert '_DebtReminderCard' not in dash, 'A debt amount/reminder card is still visible on dashboard'
assert 'ReceivablesService.summary()' not in dash, 'Dashboard still loads private debt totals'
assert 'ReminderCenterScreen()' in (root/'lib/main.dart').read_text(), 'Bell reminder route removed'
assert 'IndexedStack(index: selected' in (root/'lib/main.dart').read_text(), 'Bottom tabs lost scroll/state retention'

backup = (root/'lib/services/backup_service.dart').read_text()
assert 'local_face_preferred_v30' not in backup, 'Do not export device biometric preferences'
assert "'databaseVersion': 15" in backup, 'SQLite schema must remain v15'
assert "'cash_card_style'" in backup, 'Premium card style backup missing'
security = (root/'lib/services/biometric_security.dart').read_text()
assert "static const key = 'local_biometrics_enabled_v1';" in security, 'Old biometrics preference lost'
assert "static const faceKey = 'local_face_preferred_v30';" in security
assert 'return types.contains(BiometricType.face);' in security
assert 'if (!await PinSecurity.enabled || !await faceAvailable) return false;' in security
print('OK: Build30 privacy, sculpted summary tiles, bottom motion, Android biometric face preference, PIN fallback')
