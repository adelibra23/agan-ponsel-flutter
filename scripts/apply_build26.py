#!/usr/bin/env python3
"""Safe idempotent Build25 -> Build26 metadata/UI wiring patch.

Run after extracting Build26 ZIP into an existing Build25 repository.
This script neither touches any SQLite database file nor Android signing.
"""
from pathlib import Path
import re


def change(path, transform):
    file = Path(path)
    if not file.exists():
        raise SystemExit(f'Missing {path}; gunakan source Build25 lengkap')
    before = file.read_text()
    after = transform(before)
    if after != before:
        file.write_text(after)
        print('PATCHED:', path)
    else:
        print('UNCHANGED:', path)


def insert(s, before, after, label):
    if after in s:
        return s
    if s.count(before) != 1:
        raise SystemExit(f'Anchor {label} tidak cocok ({s.count(before)})')
    return s.replace(before, after, 1)


def expenses(s):
    if "import 'expense_insights.dart';" not in s:
        s = insert(s, "import '../services/expenses_service.dart';",
                   "import '../services/expenses_service.dart';\nimport 'expense_insights.dart';", 'expense import')
    if 'Future<void> openInsights() async {' not in s:
        anchor = '  String csvCell(Object? value) =>'
        addition = '''  Future<void> openInsights() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ExpenseInsightsScreen(onRepeat: (source) async {
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => ExpenseEditorPage(copyFrom: source)));
        return saved == true;
      })));
    if (mounted) refresh();
  }

'''
        s = insert(s, anchor, addition + anchor, 'insights navigation')
    anchor = "appBar: AppBar(title: const Text('Pengeluaran'), actions: ["
    replacement = anchor + "\n      IconButton(tooltip: 'Insight & Anggaran',\n        icon: const Icon(Icons.insights_rounded), onPressed: openInsights),"
    s = insert(s, anchor, replacement, 'insights action')
    anchor = "        TextField(onChanged: (v) => setState(() => search = v),"
    replacement = """        OutlinedButton.icon(onPressed: openInsights,
          icon: const Icon(Icons.insights_rounded),
          label: const Text('Insight, Anggaran & Pengeluaran Favorit')),
        const SizedBox(height: 12),
""" + anchor
    s = insert(s, anchor, replacement, 'insights entry card')
    return s


def backup(s):
    original = "'daily_sales_target', 'app_template_style', 'app_font_family', 'reminder_message_template',"
    updated = "'daily_sales_target', 'app_template_style', 'app_font_family', 'reminder_message_template',\n    'expense_budget_settings',"
    return insert(s, original, updated, 'backup profile budget preference')


def pubspec(s):
    if 'version: 1.6.0+26' in s:
        return s
    return insert(s, 'version: 1.5.0+25', 'version: 1.6.0+26', 'version')


def legacy_guard(s, *, build):
    # Legacy Build24/25 checks should enforce minimum compatibility rather than
    # an exact app version/artifact that breaks every future feature release.
    marker = '# Build26 forward-compatible version guard'
    if marker in s:
        return s
    outdated = ["version: 1.5.0+25"]
    if build == 24:
        outdated.append('AGAN-PONSEL-v1.5.0-Build25-APK')
    else:
        outdated.append('Build25-APK')
    for token in outdated:
        pattern = r"'" + re.escape(token) + r"'\s*,?"
        s, occurrences = re.subn(pattern, '', s, count=1)
        if occurrences != 1:
            raise SystemExit(f'Legacy Build{build} check expected exactly one {token}')
    minimum = '1, 4, 0, 24' if build == 24 else '1, 5, 0, 25'
    addon = r'''

# Build26 forward-compatible version guard
import re as _re_build26
_version = _re_build26.search(r'(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)',
    Path('pubspec.yaml').read_text())
assert _version, 'App version missing'
_values = tuple(int(x) for x in _version.groups())
assert _values >= (__MIN__), 'Requires Build__BUILD__ or newer'
'''
    return s + addon.replace('__MIN__', minimum).replace('__BUILD__', str(build))


def workflow(s):
    prev = 'AGAN-PONSEL-v1.5.0-Build25-APK'
    current = 'AGAN-PONSEL-v1.6.0-Build26-APK'
    if prev in s:
        s = s.replace(prev, current)
    elif current not in s:
        raise SystemExit('Unrecognized APK artifact name; Build25 workflow required')
    if 'scripts/check_build26.py' not in s:
        anchor = '      - name: Analyze Flutter code'
        step = '''      - name: Check Build26 finance insights and backup settings
        run: |
          python3 scripts/check_build26.py
          python3 scripts/smoke_budget_backup.py

'''
        s = insert(s, anchor, step + anchor, 'Build26 checks')
    if 'test/build26_insights_test.dart' not in s:
        anchor = 'test/build24_expenses_test.dart'
        s = insert(s, anchor, anchor + ' test/build26_insights_test.dart', 'Build26 unit test')
    return s

change('lib/screens/expenses_v2.dart', expenses)
change('lib/services/backup_service.dart', backup)
change('pubspec.yaml', pubspec)
change('scripts/check_build24.py', lambda s: legacy_guard(s, build=24))
change('scripts/check_build25.py', lambda s: legacy_guard(s, build=25))
change('.github/workflows/build-apk.yml', workflow)
print('OK: Build26 wiring installed; no database schema changes')
