#!/usr/bin/env python3
"""Fix Build31 package_info_plus/win32 solver clash without altering app data.

Safe to execute more than once. Aborts before modifying files if source is not
Build31, required unchanged anchors are absent, or either file has drifted.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / 'pubspec.yaml'
GUARD = ROOT / 'scripts/check_build31.py'
REPLACEMENTS = {
    PUBSPEC: (
        '  package_info_plus: ^8.3.1',
        '  package_info_plus: ^10.2.2',
    ),
    GUARD: (
        "'package_info_plus: ^8.3.1'",
        "'package_info_plus: ^10.2.2'",
    ),
}

if not PUBSPEC.is_file() or not GUARD.is_file():
    raise SystemExit('ERROR: Tidak menemukan source Build31. Jalankan dari folder repository AGAN PONSEL.')
source = PUBSPEC.read_text(encoding='utf-8')
if not re.search(r'(?m)^version:\s*2\.1\.0\+31\s*$', source):
    raise SystemExit('ERROR: Patch khusus untuk AGAN PONSEL v2.1.0+31; source tidak diubah.')
if '  flutter_secure_storage: ^11.2.0' not in source:
    raise SystemExit('ERROR: Versi flutter_secure_storage berbeda. Periksa source, tidak diubah.')
if '  shared_preferences_android: 2.4.28' not in source:
    raise SystemExit('ERROR: Penguncian shared_preferences_android 2.4.28 hilang. Tidak diubah.')

pending = {}
for target, (old, new) in REPLACEMENTS.items():
    original = target.read_text(encoding='utf-8')
    if original.count(old) == 1 and original.count(new) == 0:
        pending[target] = original.replace(old, new, 1)
    elif original.count(old) == 0 and original.count(new) == 1:
        pending[target] = original
    else:
        raise SystemExit(f'ERROR: Isi file {target.relative_to(ROOT)} tidak sesuai; tidak ada perubahan.')

# Validate BOTH planned contents before writing EITHER file.
if 'package_info_plus: ^10.2.2' not in pending[PUBSPEC]:
    raise SystemExit('ERROR: Dependency tidak terpasang; patch dibatalkan.')
if "'package_info_plus: ^10.2.2'" not in pending[GUARD]:
    raise SystemExit('ERROR: Guard Build31 tidak kompatibel; patch dibatalkan.')

changed = []
for target, content in pending.items():
    if target.read_text(encoding='utf-8') != content:
        target.write_text(content, encoding='utf-8')
        changed.append(str(target.relative_to(ROOT)))

print('PASS: Build31 package_info_plus ^10.2.2 and static guard synchronized.')
if changed:
    print('Modified: ' + ', '.join(changed))
else:
    print('No changes needed; hotfix already applied.')
