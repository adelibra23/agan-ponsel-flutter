#!/usr/bin/env python3
"""Idempotent, safe Build24 hotfix. Adds lint dependency in existing pubspec.
Does NOT overwrite Build23 cloud/alarm dependencies or existing version.
"""
from pathlib import Path
import re

pub = Path('pubspec.yaml')
if not pub.exists():
    raise SystemExit('Tidak menemukan pubspec.yaml; jalankan dari root proyek Flutter')
s = pub.read_text(encoding='utf-8')
if not re.search(r'(?m)^version: 1\.4\.0\+24\s*$', s):
    raise SystemExit('Hotfix hanya untuk Build24 (version: 1.4.0+24); berhenti agar aman')
for name in ('workmanager:', 'google_sign_in:', 'flutter_local_notifications:',
             'shared_preferences_android: 2.4.28'):
    if name not in s:
        raise SystemExit(f'Fitur/dependency Build23 hilang: {name}; jangan lanjut')
if '  flutter_lints:' in s:
    print('flutter_lints sudah tersedia; tidak diubah')
else:
    anchor = '  flutter_native_splash: ^2.4.6'
    if s.count(anchor) != 1:
        raise SystemExit('Letak dev_dependencies tidak sesuai; tidak mengubah pubspec')
    s = s.replace(anchor, anchor + '\n  flutter_lints: ^6.0.0', 1)
    pub.write_text(s, encoding='utf-8')
    print('flutter_lints ditambahkan, dependency Build23 tidak berubah')
