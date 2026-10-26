#!/usr/bin/env python3
"""Smoke check for the exact Build31 About visible-copy hotfix."""
from pathlib import Path
import subprocess
import sys
import re

root = Path(__file__).resolve().parent.parent
pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
assert re.search(r'(?m)^version:\s*2\.1\.0\+31\s*$', pubspec), 'Expected Build31'
about = (root / 'lib/screens/settings/about_store.dart').read_text(encoding='utf-8')
wrapper = (root / 'lib/screens/settings/settings_pages.dart').read_text(encoding='utf-8')
assert "const _AboutSectionTitle('Tentang Aplikasi')," in about
assert 'secara offline' in about
assert 'data transaksi tersimpan lokal' in about
assert 'Google Drive' in about and 'WhatsApp' in about
assert 'class AboutAganScreen' in wrapper and 'AboutStoreScreen()' in wrapper
assert "'databaseVersion': 15" in (root / 'lib/services/backup_service.dart').read_text(encoding='utf-8')
result = subprocess.run([sys.executable, 'scripts/check_labels.py'], cwd=root, text=True,
                        capture_output=True)
if result.returncode:
    raise SystemExit(result.stdout + result.stderr)
assert 'OK:' in result.stdout
print('PASS: Build31 copy, route and SQLite v15 retained')
