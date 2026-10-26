#!/usr/bin/env python3
"""Check dependency solver hotfix and protect previous safety overrides."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
guard = (ROOT / 'scripts/check_build31.py').read_text(encoding='utf-8')
expected = [
    (r'(?m)^version:\s*2\.1\.0\+31\s*$', pubspec, 'Build31 version'),
    (r'(?m)^  package_info_plus: \^10\.2\.2\s*$', pubspec, 'compatible package_info_plus'),
    (r'(?m)^  flutter_secure_storage: \^11\.2\.0\s*$', pubspec, 'secure storage'),
    (r'(?m)^  shared_preferences_android: 2\.4\.28\s*$', pubspec, 'safe Android preferences'),
]
for pat, data, name in expected:
    assert re.search(pat, data), f'Missing {name}'
assert "'package_info_plus: ^10.2.2'" in guard, 'Build31 guard still expects obsolete version'
assert "'package_info_plus: ^8.3.1'" not in guard, 'Old package constraint in Build31 guard'
assert 'package_info_plus: ^8.3.1' not in pubspec, 'Old package constraint in pubspec'
assert "'databaseVersion': 15" in (ROOT / 'lib/services/backup_service.dart').read_text(encoding='utf-8'), 'Backup schema changed unexpectedly'
assert (ROOT / 'lib/screens/settings/about_store.dart').is_file(), 'Editable About source missing'
assert 'PackageInfo.fromPlatform()' in (ROOT / 'lib/screens/settings/about_store.dart').read_text(encoding='utf-8'), 'About package info API missing'
assert 'AGAN-PONSEL-v2.1.0-Build31-APK' in (ROOT / '.github/workflows/build-apk.yml').read_text(encoding='utf-8'), 'Build31 workflow changed'
print('PASS: Build31 dependency hotfix and existing features verified.')
