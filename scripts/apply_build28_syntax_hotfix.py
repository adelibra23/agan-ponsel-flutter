#!/usr/bin/env python3
"""Fix a single unmatched ')' in AGAN PONSEL Build28 digital list.

Does not modify SQLite, app version, native Android, or any other file.
Fail safely if the project has a different source shape.
"""
from pathlib import Path

path = Path('lib/screens/digital_plus.dart')
if not path.is_file():
    raise SystemExit('ERROR: lib/screens/digital_plus.dart tidak ditemukan; jalankan dari root project Build 28.')
source = path.read_text(encoding='utf-8')
if 'class DigitalPlusScreen extends StatefulWidget' not in source:
    raise SystemExit('ERROR: Ini bukan source DigitalPlusScreen Build 28.')
# Correct closing sequence: ListView(children: [...]) and RefreshIndicator(...).
wrong = '          ])));\n      }),'
right = '          ]));\n      }),'
if source.count(wrong) == 1:
    changed = source.replace(wrong, right, 1)
    assert len(source) - len(changed) == 1
    path.write_text(changed, encoding='utf-8')
    print('PATCHED: lib/screens/digital_plus.dart (1 tanda kurung berlebih dihapus)')
elif wrong not in source and source.count(right) == 1:
    print('OK: Syntax Build 28 sudah diperbaiki; tidak ada perubahan tambahan.')
else:
    raise SystemExit('ERROR: Pola penutup widget tidak cocok. Jangan memaksa patch; kirim isi file untuk diperiksa.')
