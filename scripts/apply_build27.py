#!/usr/bin/env python3
"""Apply AGAN PONSEL Build27 on top of Build26, no user data touched.

Update source files only, fail before changing anything if the repository is
not in the expected state. Running twice is safe.
"""
from pathlib import Path
import re

MARKER = '// AGAN_PONSEL_RESTOCK_V14'


def replace_once(text: str, before: str, after: str, label: str) -> str:
    count = text.count(before)
    if count != 1:
        raise ValueError(f'{label}: expected 1 anchor, found {count}')
    return text.replace(before, after, 1)


def db_patch(text):
    if MARKER in text:
        return text
    text = replace_once(text, 'version: 13,', 'version: 14,', 'database version')
    anchor = '        await _createExpensesV13(db);'
    if len(re.findall(r'(?m)^' + re.escape(anchor) + r'$', text)) != 2:
        raise ValueError('Expected v13 method call in both onCreate and onOpen')
    text = re.sub(r'(?m)^' + re.escape(anchor) + r'$',
        anchor + '\n        await _createRestockV14(db);', text)
    before = '''        if (oldVersion < 13) {
          await _createExpensesV13(db);
        }'''
    after = before + '''
        if (oldVersion < 14) {
          await _createRestockV14(db);
        }'''
    text = replace_once(text, before, after, 'v14 migration')
    method = """  // AGAN_PONSEL_RESTOCK_V14
  /// v14: purchase planning, supplier contacts, stock receipt history.
  /// New tables only; preexisting products, sales and cash never reset.
  static Future<void> _createRestockV14(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS suppliers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      phone TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS restock_orders(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_id INTEGER,
      status TEXT NOT NULL DEFAULT 'draft',
      notes TEXT NOT NULL DEFAULT '',
      estimated_total INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      received_at TEXT NOT NULL DEFAULT '',
      FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS restock_order_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      qty INTEGER NOT NULL CHECK(qty > 0),
      unit_cost INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(order_id) REFERENCES restock_orders(id)
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_restock_orders_status '
      'ON restock_orders(status, id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_restock_order_items_parent '
      'ON restock_order_items(order_id)');
  }

"""
    return replace_once(text, '  /// v13: richer expense details',
        method + '  /// v13: richer expense details', 'insert v14 schema')


def backup_patch(text):
    new_table = "'suppliers', 'restock_orders', 'restock_order_items',"
    if new_table not in text:
        text = replace_once(text,
            "'receivable_payment_edits', 'receivable_bon_events',",
            "'receivable_payment_edits', 'receivable_bon_events',\n    " + new_table,
            'backup table list')
    text = replace_once(text, "'databaseVersion': 13,",
        "'databaseVersion': 14,", 'backup schema version')
    pattern = r"(\[\s*4\s*,\s*5\s*,\s*6\s*,\s*7\s*,\s*8\s*,\s*9\s*,\s*10\s*,\s*11\s*,\s*12\s*,\s*13\s*)\]\.contains\(payload\['databaseVersion'\]\)"
    text, number = re.subn(pattern,
        lambda m: m.group(1) + ', 14].contains(payload[\'databaseVersion\'])', text, count=1)
    if number != 1:
        raise ValueError('backup whitelist v4–v13 missing or already modified')
    return text


def more_patch(text):
    if "import 'restock_center.dart';" not in text:
        text = replace_once(text, "import 'inventory.dart';",
            "import 'inventory.dart';\nimport 'restock_center.dart';", 'restock import')
    if 'title: \'Restock & Supplier\'' not in text:
        anchor = "      _MenuItem(icon: Icons.sim_card_rounded,"
        addition = """      _MenuItem(icon: Icons.local_shipping_rounded, color: const Color(0xFF008D83),
        title: 'Restock & Supplier',
        subtitle: 'Rencana belanja, kontak pemasok dan konfirmasi barang masuk',
        onTap: () => open(const RestockCenterScreen())),
"""
        text = replace_once(text, anchor, addition + anchor, 'restock More menu')
    return text


def version_patch(text):
    return replace_once(text, 'version: 1.6.0+26',
        'version: 1.7.0+27', 'Build27 pubspec version')


def workflow_patch(text):
    text = replace_once(text, 'AGAN-PONSEL-v1.6.0-Build26-APK',
        'AGAN-PONSEL-v1.7.0-Build27-APK', 'workflow artifact')
    anchor = '      - name: Analyze Flutter code'
    addition = '''      - name: Validate Build27 suppliers and restock migration
        run: |
          python3 scripts/check_build27.py
          python3 scripts/smoke_restock_v14.py

'''
    text = replace_once(text, anchor, addition + anchor, 'Build27 CI test')
    text = replace_once(text, 'test/build26_insights_test.dart',
        'test/build26_insights_test.dart test/build27_restock_test.dart',
        'Build27 Flutter unit tests')
    return text


def checks_patch(text, *, name):
    # v13 behavior remains mandatory; only exact current-schema checks move.
    text = text.replace("'databaseVersion': 13", "'databaseVersion': 14")
    text = text.replace('version: 13', 'version: 14')
    text = text.replace(r'version:\s*13\s*,', r'version:\s*14\s*,')
    if name == 'check_build26.py':
        text = text.replace('version: 1.6.0+26', 'version: 1.7.0+27')
        text = text.replace('AGAN-PONSEL-v1.6.0-Build26-APK',
            'AGAN-PONSEL-v1.7.0-Build27-APK')
        text = text.replace('SQLite v13', 'SQLite v14')
        text = text.replace('unchanged SQLite v13', 'SQLite v14 with additive restock schema')
        text = text.replace('SQLite schema version must stay v13', 'SQLite schema version must be v14')
    if name == 'smoke_budget_backup.py':
        text = text.replace(r"'databaseVersion':\s*13\b", r"'databaseVersion':\s*14\b")
    return text


def main():
    base = Path.cwd()
    if not (base / 'scripts/apply_build26.py').exists():
        raise SystemExit('Build26 belum dipasang. Ekstrak ZIP Build26 lalu jalankan apply_build26.py terlebih dahulu.')
    version = (base / 'pubspec.yaml').read_text()
    if 'version: 1.7.0+27' in version:
        # The combined archive also contains the original Build26 regression
        # checks. Repair them if the ZIP was accidentally extracted again.
        for name in ['check_build24.py', 'check_build25.py', 'check_build26.py',
                     'smoke_expenses_v13.py', 'smoke_budget_backup.py']:
            target = base / 'scripts' / name
            if target.exists():
                before = target.read_text()
                after = checks_patch(before, name=name)
                if after != before:
                    target.write_text(after)
                    print('REPAIRED', target.relative_to(base))
        print('OK: Build27 already applied')
        return
    if 'version: 1.6.0+26' not in version:
        raise SystemExit('Build27 membutuhkan source Build26 (version: 1.6.0+26).')
    paths = {
        'lib/core/database.dart': db_patch,
        'lib/services/backup_service.dart': backup_patch,
        'lib/screens/others.dart': more_patch,
        'pubspec.yaml': version_patch,
        '.github/workflows/build-apk.yml': workflow_patch,
    }
    for name in ['check_build24.py', 'check_build25.py', 'check_build26.py',
                 'smoke_expenses_v13.py', 'smoke_budget_backup.py']:
        paths[f'scripts/{name}'] = lambda s, n=name: checks_patch(s, name=n)
    # Prepare all modifications before writing any file to reduce partial update risk.
    prepared = {}
    for name, transform in paths.items():
        target = base / name
        if not target.exists():
            raise SystemExit(f'Tidak ada {name}; source Build26 belum lengkap.')
        current = target.read_text()
        try:
            prepared[target] = transform(current)
        except Exception as e:
            raise SystemExit(f'PATCH FAILED pada {name}: {e}') from e
    for target, output in prepared.items():
        if output != target.read_text():
            target.write_text(output)
            print('UPDATED', target.relative_to(base))
    print('OK: Build27 patched; no SQLite data file modified')


if __name__ == '__main__':
    main()
