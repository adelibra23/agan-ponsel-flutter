#!/usr/bin/env python3
"""Build28 CI Hotfix 2: preserve integration guards across dart format rewrites.

Only modifies scripts/check_build28.py. No Flutter code, database, or app data changes.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
file = root / 'scripts/check_build28.py'
if not file.is_file():
    raise SystemExit('check_build28.py tidak ditemukan; jalankan dari repo AGAN PONSEL')
if not (root / 'pubspec.yaml').exists() or 'version: 1.8.0+28' not in (root / 'pubspec.yaml').read_text():
    raise SystemExit('Hotfix ini hanya untuk source AGAN PONSEL Build28 (1.8.0+28)')
s = file.read_text()
marker = '# BUILD28_FORMAT_STABLE_MARKERS'
if marker in s:
    print('OK: Build28 format-stable checks already applied')
    raise SystemExit(0)
old = "    for marker in markers:\n        assert marker in text, f'{path} missing {marker!r}'"
if s.count(old) != 1:
    raise SystemExit('Struktur pemeriksaan Build28 berbeda: tidak ada perubahan yang diterapkan')
new = """    for marker in markers:
        # BUILD28_FORMAT_STABLE_MARKERS: dart format may insert line breaks
        # in member-access chains (SharePlus.instance.share) and arguments.
        # Preserve every required marker, but ignore formatting whitespace.
        compact = lambda value: re.sub(r'\\s+', '', value)
        assert compact(marker) in compact(text), f'{path} missing {marker!r}'"""
s = s.replace(old, new, 1)
file.write_text(s)
print('PATCHED: scripts/check_build28.py (format-stable requirements)')
