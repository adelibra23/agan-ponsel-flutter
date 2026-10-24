#!/usr/bin/env python3
"""Fix Flutter showDialog named-context call (Build27 Analyzer Hotfix 2).

Apply inside an existing AGAN PONSEL Build27 repository after extracting ZIP.
Does not modify database, app ID, backup schema, dependencies or signing.
"""
from pathlib import Path
import re

root = Path.cwd()
version = root / 'pubspec.yaml'
file = root / 'lib/screens/restock_center.dart'
if not version.is_file() or not file.is_file():
    raise SystemExit('ERROR: jalankan dari root repository AGAN PONSEL Build27')
if 'version: 1.7.0+27' not in version.read_text(encoding='utf-8'):
    raise SystemExit('ERROR: hotfix ini khusus AGAN PONSEL v1.7.0 Build27')
source = file.read_text(encoding='utf-8')
# Keep indentation/newlines intact; the Dart formatter will format the result.
wrong = r'showDialog<bool>(context, builder:'
correct = r'showDialog<bool>(context: context, builder:'
if wrong not in source:
    if correct in source or re.search(r'showDialog<bool>\s*\(\s*context\s*:\s*context\s*,', source):
        print('OK: pemanggilan showDialog sudah benar; tidak ada perubahan')
        raise SystemExit(0)
    raise SystemExit('ERROR: kode sumber berbeda dari Build27 GitHub; patch dibatalkan')
if source.count(wrong) != 1:
    raise SystemExit('ERROR: jumlah lokasi yang perlu diperbaiki bukan satu; patch dibatalkan')
if 'Konfirmasi Barang Diterima?' not in source:
    raise SystemExit('ERROR: halaman konfirmasi restock tidak ditemukan; patch dibatalkan')
file.write_text(source.replace(wrong, correct, 1), encoding='utf-8')
print('OK: parameter context pada dialog konfirmasi Restock diperbaiki')
