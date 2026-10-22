#!/usr/bin/env python3
"""Static safety check for Build 24 format hotfix; no Flutter SDK required."""
from pathlib import Path
import re

src = Path('lib/screens/expenses_v2.dart').read_text(encoding='utf-8')
pub = Path('pubspec.yaml').read_text(encoding='utf-8')
assert "${row['reason']}\\n" in src, 'Expense audit reason separator missing'
assert "${row['occurred_at']}\\n" in src, 'Expense audit time separator missing'
assert "${rupiah((row['old_amount'] as num).toInt())}\\n→ " in src, 'Expense audit arrow separator missing'
assert 'flutter_lints: ^6.0.0' in pub, 'Missing flutter_lints dev dependency'
assert re.search(r'(?m)^version: 1\.4\.0\+24$', pub), 'Do not change app version unexpectedly'
assert 'shared_preferences_android: 2.4.28' in pub, 'Critical startup plugin override missing'
print('PASS: expense audit interpolation fixed and Flutter lint dependency configured')
