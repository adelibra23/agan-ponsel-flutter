#!/usr/bin/env python3
"""Regression check for formatting-insensitive, non-bypassed Build28 CI checks."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
path = root / 'scripts/check_build28.py'
s = path.read_text()
assert '# BUILD28_FORMAT_STABLE_MARKERS' in s, 'Hotfix belum diterapkan'
assert 'assert compact(marker) in compact(text)' in s, 'Pemeriksaan marker tidak aktif'
assert 'for path, markers in checks.items():' in s
assert 'for marker in markers:' in s
assert 'SharePlus.instance.share' in s
assert "'lib/screens/store_notes.dart'" in s
assert 'assert db.count(' in s and 'assert re.search(' in s
assert (root / 'pubspec.yaml').read_text().find('version: 1.8.0+28') >= 0

# Both ordinary and dart-format-wrapped member access must be accepted.
compact = lambda value: re.sub(r'\s+', '', value)
for variant in ('SharePlus.instance.share', 'SharePlus.instance\n            .share',
                'SharePlus\n  .instance\n    .share'):
    assert compact('SharePlus.instance.share') in compact(variant)
# Still reject missing required feature rather than suppressing validation.
assert compact('SharePlus.instance.share') not in compact('Clipboard.setData(ClipboardData(text: note))')

print('PASS: CI guard checks all Build28 features regardless of dart-format whitespace')
