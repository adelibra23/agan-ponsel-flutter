#!/usr/bin/env python3
"""Static Build27 hotfix guard; does not substitute for flutter analyze."""
from pathlib import Path
import re
root = Path.cwd()
source = (root / 'lib/screens/restock_center.dart').read_text(encoding='utf-8')
version = (root / 'pubspec.yaml').read_text(encoding='utf-8')
assert 'version: 1.7.0+27' in version, 'Project version must be 1.7.0+27'
assert not re.search(r'showDialog\s*<\s*bool\s*>\s*\(\s*context\s*,\s*builder\s*:', source), 'Positional context still present'
assert re.search(r'showDialog\s*<\s*bool\s*>\s*\(\s*context\s*:\s*context\s*,\s*builder\s*:', source), 'Corrected dialog not found'
assert 'Konfirmasi Barang Diterima?' in source, 'Restock confirmation missing'
assert 'RestockService.receiveOrder(' in source, 'Restock receipt handler missing'
print('PASS: dialog konfirmasi Restock menggunakan named context dan fitur penerimaan tetap ada')
