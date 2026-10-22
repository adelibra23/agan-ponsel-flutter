#!/usr/bin/env python3
"""Idempotent patcher for AGAN PONSEL v1.3.0 Build23 -> v1.4.0 Build24.
Run only on clean or committed Build23 repository after extracting patch ZIP.
Never renames an Android package or deletes/migrates data outside SQLite.
"""
from pathlib import Path
import re


def edit(path, transform):
    p = Path(path)
    if not p.exists():
        raise SystemExit(f'Missing file {path}: use Build23 source')
    source = p.read_text()
    result = transform(source)
    if result == source:
        print('UNCHANGED', path)
    else:
        p.write_text(result)
        print('PATCHED', path)


def replace_once(source, before, after, *, name):
    if after in source: return source
    count = source.count(before)
    if count != 1: raise SystemExit(f'{name}: expected 1 anchor, found {count}')
    return source.replace(before, after, 1)


def patch_others(s):
    if "import 'expenses_v2.dart';" not in s:
        s = replace_once(s, "import 'cash_screen.dart';", "import 'cash_screen.dart';\nimport 'expenses_v2.dart';", name='expenses import')
    start = s.find('class ExpensesScreen extends StatefulWidget {')
    end = s.find('class DigitalScreen extends StatefulWidget {')
    if start >= 0 and end > start:
        s = s[:start] + '''/// Compatibility wrapper keeps existing menu routes stable.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});
  @override
  Widget build(BuildContext context) => const ExpensesManagementScreen();
}

''' + s[end:]
    elif 'class ExpensesScreen extends StatelessWidget' not in s:
        raise SystemExit('ExpensesScreen anchor missing; stop to avoid overwriting new features')
    return s


def patch_db(s):
    if 'static Future<void> _createExpensesV12' in s: return s
    s = replace_once(s, 'version: 11,', 'version: 12,', name='database version')
    s = s.replace('await _createPaymentCorrections(db);',
        'await _createPaymentCorrections(db);\n        await _createExpensesV12(db);', 2)
    marker = '        if (oldVersion < 11) {\n          await _createPaymentCorrections(db);\n        }'
    if marker not in s:
        raise SystemExit('database onUpgrade v11 anchor not found')
    s = s.replace(marker, marker + '\n        if (oldVersion < 12) {\n          await _createExpensesV12(db);\n        }', 1)
    method = '''  /// v12: additive expense categories, manual date/time and audit trail.
  static Future<void> _createExpensesV12(DatabaseExecutor db) async {
    await db.execute(''' + "'''" + '''CREATE TABLE IF NOT EXISTS expense_categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )''' + "'''" + ''');
    await db.execute(''' + "'''" + '''CREATE TABLE IF NOT EXISTS expense_audit(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_id INTEGER NOT NULL,
      action TEXT NOT NULL,
      old_amount INTEGER NOT NULL,
      new_amount INTEGER NOT NULL,
      reason TEXT NOT NULL,
      snapshot TEXT NOT NULL DEFAULT '',
      occurred_at TEXT NOT NULL
    )''' + "'''" + ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expense_audit_item ON expense_audit(expense_id)');
    final cols = (await db.rawQuery('PRAGMA table_info(expenses)'))
        .map((row) => row['name'] as String).toSet();
    const fields = <String, String>{
      'category_id': 'INTEGER',
      'payment_method': "TEXT NOT NULL DEFAULT 'Tunai'",
      'note': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    };
    for (final e in fields.entries) {
      if (!cols.contains(e.key)) {
        await db.execute('ALTER TABLE expenses ADD COLUMN ${e.key} ${e.value}');
      }
    }
    final defaults = ['Lainnya', 'Operasional', 'Sparepart', 'Listrik & Air',
      'Internet & Pulsa', 'Transportasi', 'Sewa', 'Gaji', 'Peralatan', 'Lain-lain'];
    for (final name in defaults) {
      await db.rawInsert('INSERT OR IGNORE INTO expense_categories(name,archived,created_at) '
        'VALUES (?,0,?)', [name, DateTime.now().toIso8601String()]);
    }
  }

'''
    anchor = '  // v11:'
    if anchor not in s:
        raise SystemExit('v11 method comment missing')
    return s.replace(anchor, method + anchor, 1)


def patch_backup(s):
    if "'expense_categories'" in s and "'expense_audit'" in s and "'app_font_family'" in s:
        return s
    anchor = "'products', 'sales', 'services', 'customers', 'expenses',"
    if anchor not in s: raise SystemExit('backup table anchor missing')
    s = s.replace(anchor, anchor + "\n    'expense_categories', 'expense_audit',", 1)
    # Note: above anchor is also in requiredTables. Only tables should be extended.
    s = replace_once(s, "'daily_sales_target', 'app_template_style', 'reminder_message_template',",
        "'daily_sales_target', 'app_template_style', 'app_font_family', 'reminder_message_template',", name='font backup')
    s = re.sub(r"'databaseVersion':\s*11", "'databaseVersion': 12", s, count=1)
    s = s.replace("[4, 5, 6, 7, 8, 9, 10, 11]", "[4, 5, 6, 7, 8, 9, 10, 11, 12]")
    return s


def patch_main(s):
    if 'aganFontFamily.addListener' in s: return s
    match = re.search(r"(?m)^(?P<indent>[ ]*)(?P<decl>final prefs = await SharedPreferences.getInstance\(\);)\n[ ]*runApp\(AganApp\(", s)
    if match is None:
        raise SystemExit('startup font anchor not found')
    indent = match.group('indent')
    s = s[:match.start()] + indent + match.group('decl') + "\n" + indent + "final family = prefs.getString('app_font_family') ?? 'Roboto';\n" + indent + "aganFontFamily.value = appFontChoices.containsKey(family) ? family : 'Roboto';\n" + indent + "runApp(AganApp(" + s[match.end():]
    anchor = 'class _AganAppState extends State<AganApp> {'
    s = replace_once(s, anchor, anchor + '''
  @override
  void initState() {
    super.initState();
    aganFontFamily.addListener(_onFontChanged);
  }

  void _onFontChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    aganFontFamily.removeListener(_onFontChanged);
    super.dispose();
  }
''', name='font listener')
    return s


def patch_pubspec(s):
    s = replace_once(s, 'version: 1.3.0+23', 'version: 1.4.0+24', name='app version')
    s = s.replace('image: assets/branding/agan_launcher.png\n  android_12:',
                  'image: assets/branding/splash_blank.png\n  android_12:', 1)
    s = s.replace('    image: assets/branding/agan_launcher.png\n  android: true',
                  '    image: assets/branding/splash_blank.png\n  android: true', 1)
    # Native Android system splash remains required; blank transparent image
    # prevents duplicate launcher logo, leaving the custom Flutter splash alone.
    return s


def patch_workflow(s):
    s = s.replace('AGAN-PONSEL-v1.3.0-Build23-APK', 'AGAN-PONSEL-v1.4.0-Build24-APK')
    if 'test/build24_expenses_test.dart' not in s:
        anchor = 'test/build23_schedule_test.dart'
        if anchor not in s: raise SystemExit('Build23 unit-test anchor missing')
        s = s.replace(anchor, anchor+' test/build24_expenses_test.dart', 1)
    if 'Check AGAN PONSEL Build24' not in s:
        anchor = '      - name: Analyze Flutter code'
        if anchor not in s: raise SystemExit('workflow flutter analyze anchor missing')
        s = s.replace(anchor, '''      - name: Check AGAN PONSEL Build24
        run: |
          python3 scripts/check_build24.py
          python3 scripts/smoke_expenses_v12.py

''' + anchor, 1)
    return s

edit('lib/screens/others.dart', patch_others)
edit('lib/core/database.dart', patch_db)
edit('lib/services/backup_service.dart', patch_backup)
edit('lib/main.dart', patch_main)
edit('pubspec.yaml', patch_pubspec)
edit('.github/workflows/build-apk.yml', patch_workflow)
print('Build24 patch completed. Check scripts/check_build24.py and Flutter Actions.')
