#!/usr/bin/env python3
"""Apply Build25 CI/version metadata to an existing *successful Build24* checkout.

Does not replace the Build24 pubspec or workflow: preserves flutter_lints,
Google Drive/alarms, startup safety, and WhatsApp webhook tests.
Idempotent on a repeated call.
"""
from pathlib import Path


def update(path: str, old: str, new: str) -> None:
    file = Path(path)
    if not file.exists():
        raise SystemExit(f'File required but not found: {path}')
    source = file.read_text()
    if new in source and old not in source:
        print('ALREADY UPDATED:', path)
        return
    if source.count(old) != 1:
        raise SystemExit(f'Stop: unexpected version of {path}; need exactly one anchor: {old!r}')
    file.write_text(source.replace(old, new, 1))
    print('UPDATED:', path)


update('pubspec.yaml', 'version: 1.4.0+24', 'version: 1.5.0+25')
update('.github/workflows/build-apk.yml',
       'AGAN-PONSEL-v1.4.0-Build24-APK', 'AGAN-PONSEL-v1.5.0-Build25-APK')
workflow = Path('.github/workflows/build-apk.yml')
source = workflow.read_text()
name = '      - name: Smoke test expense quantities and category visuals v13'
if name not in source:
    marker = '      - name: Analyze Flutter code'
    if source.count(marker) != 1:
        raise SystemExit('Stop: Flutter analyzer step missing or ambiguous')
    source = source.replace(marker, '''      - name: Smoke test expense quantities and category visuals v13
        run: |
          python3 scripts/check_build25.py
          python3 scripts/smoke_expenses_v13.py

''' + marker, 1)
    workflow.write_text(source)
    print('UPDATED: v13 checks in GitHub Actions')
else:
    print('ALREADY UPDATED: v13 checks')

check = Path('scripts/check_build24.py')
if not check.exists():
    raise SystemExit('Stop: Build24 check missing')
s = check.read_text()
for old, new in [
    ("'version: 12'", "'version: 13'"),
    ("'databaseVersion': 12", "'databaseVersion': 13"),
    ("'version: 1.4.0+24'", "'version: 1.5.0+25'"),
    ('AGAN-PONSEL-v1.4.0-Build24-APK', 'AGAN-PONSEL-v1.5.0-Build25-APK'),
]:
    if old in s:
        assert s.count(old) == 1, (check, old)
        s = s.replace(old, new, 1)
    elif new not in s:
        raise SystemExit(f'Stop: unknown Build24 checker token: {old}')
check.write_text(s)
print('UPDATED: Build24 compatibility checks support v13')
print('OK: Build25 meta update complete. All existing CI features remain.')
