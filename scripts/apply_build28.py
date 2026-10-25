#!/usr/bin/env python3
"""AGAN PONSEL v1.8.0 Build28 source patch on top of verified Build27.
Does not access the Android SQLite file, package name, signing or app data.
All required anchors are validated BEFORE any files are rewritten.
"""
from pathlib import Path
import re

ROOT = Path.cwd()
VERSION_OLD = 'version: 1.7.0+27'
VERSION_NEW = 'version: 1.8.0+28'

def replace_once(s, old, new, label):
    count = s.count(old)
    if count != 1:
        raise ValueError(f'{label}: expected 1 anchor; found {count}')
    return s.replace(old, new, 1)

DB_METHOD = '''  /// v15: notes metadata, digital status + audit. Additive only.
  static Future<void> _createOperationsV15(DatabaseExecutor db) async {
    final noteColumns = (await db.rawQuery('PRAGMA table_info(store_notes)'))
        .map((r) => r['name'] as String).toSet();
    const noteFields = <String, String>{
      'category': "TEXT NOT NULL DEFAULT 'Umum'",
      'priority': "TEXT NOT NULL DEFAULT 'Normal'",
      'due_at': "TEXT NOT NULL DEFAULT ''",
      'pinned': 'INTEGER NOT NULL DEFAULT 0',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    };
    for (final e in noteFields.entries) {
      if (!noteColumns.contains(e.key)) {
        await db.execute('ALTER TABLE store_notes ADD COLUMN ${e.key} ${e.value}');
      }
    }
    final digitalColumns = (await db.rawQuery('PRAGMA table_info(digital_transactions)'))
        .map((r) => r['name'] as String).toSet();
    const digitalFields = <String, String>{
      'status': "TEXT NOT NULL DEFAULT 'Selesai'",
      'note': "TEXT NOT NULL DEFAULT ''",
      'reference_code': "TEXT NOT NULL DEFAULT ''",
      'payment_method': "TEXT NOT NULL DEFAULT 'Tunai'",
    };
    for (final e in digitalFields.entries) {
      if (!digitalColumns.contains(e.key)) {
        await db.execute('ALTER TABLE digital_transactions ADD COLUMN ${e.key} ${e.value}');
      }
    }
    await db.execute(\'''CREATE TABLE IF NOT EXISTS digital_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      old_status TEXT NOT NULL,
      new_status TEXT NOT NULL,
      old_note TEXT NOT NULL DEFAULT '',
      new_note TEXT NOT NULL DEFAULT '',
      old_reference TEXT NOT NULL DEFAULT '',
      new_reference TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      FOREIGN KEY(transaction_id) REFERENCES digital_transactions(id)
    )\''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_digital_events_parent '
      'ON digital_events(transaction_id)');
  }

'''

def patch_database(s):
    if 'static Future<void> _createOperationsV15' in s:
        if VERSION_NEW not in (ROOT/'pubspec.yaml').read_text():
            raise ValueError('Database v15 already patched, pubspec inconsistent')
        return s
    s = replace_once(s, 'version: 14,', 'version: 15,', 'database SQLite')
    old_fees = "    final fees = await aggregate('digital_transactions', 'fee');"
    new_fees = """    // Pending and failed digital transactions do not earn an admin fee.
    // Existing v14 transactions migrate with status 'Selesai'.
    final feeQuery = todayOnly
      ? "SELECT COALESCE(SUM(fee),0) AS n FROM digital_transactions WHERE status='Selesai' AND created_at LIKE ?"
      : "SELECT COALESCE(SUM(fee),0) AS n FROM digital_transactions WHERE status='Selesai'";
    final feeRows = await d.rawQuery(feeQuery,
      todayOnly ? <Object?>['${todayKey()}%'] : <Object?>[]);
    final fees = (feeRows.first['n'] as num).toInt();"""
    s = replace_once(s, old_fees, new_fees, 'dashboard earned admin fees')
    anchor = '        await _createRestockV14(db);'
    pattern = r'(?m)^' + re.escape(anchor) + r'$'
    count = len(re.findall(pattern, s))
    if count != 2:
        raise ValueError(f'Expected v14 onCreate/onOpen calls twice, found {count}')
    s = re.sub(pattern, anchor+'\n        await _createOperationsV15(db);', s)
    upgrade = '        if (oldVersion < 14) {\n          await _createRestockV14(db);\n        }'
    s = replace_once(s, upgrade, upgrade + '''
        if (oldVersion < 15) {
          await _createOperationsV15(db);
        }''', 'upgrade v15')
    return replace_once(s, '  // AGAN_PONSEL_RESTOCK_V14',
        DB_METHOD + '  // AGAN_PONSEL_RESTOCK_V14', 'v15 method insertion')

def patch_backup(s):
    s = replace_once(s,
        "'suppliers', 'restock_orders', 'restock_order_items',",
        "'suppliers', 'restock_orders', 'restock_order_items',\n    'digital_events',",
        'backup digital audit table')
    s = replace_once(s, "'databaseVersion': 14", "'databaseVersion': 15", 'backup version')
    pattern = (r'(\[\s*4\s*,\s*5\s*,\s*6\s*,\s*7\s*,\s*8\s*,\s*9\s*,\s*10\s*,\s*11\s*,\s*12\s*,\s*13\s*,\s*14\s*)\]'
               r'(\s*\.\s*contains\s*\(\s*payload\s*\[\s*[\'\"]databaseVersion[\'\"]\s*\]\s*\))')
    s, n = re.subn(pattern, lambda m: m.group(1)+', 15]'+m.group(2), s, count=1)
    if n != 1: raise ValueError('Backup restore v4–v14 whitelist missing')
    return s

def patch_others(s):
    s = replace_once(s, "import 'restock_center.dart';",
        "import 'restock_center.dart';\nimport 'digital_plus.dart';\nimport 'store_finance_plus.dart';",
        'more menu imports')
    a = s.find('class DigitalScreen extends StatefulWidget {')
    b = s.find('class ReportsScreen extends StatefulWidget {')
    if a<0 or b<=a: raise ValueError('DigitalScreen/ReportsScreen boundary unavailable')
    replacement = '''/// Compatibility entrypoint: existing menu routes still work.
class DigitalScreen extends StatelessWidget {
  const DigitalScreen({super.key});
  @override
  Widget build(BuildContext context) => const DigitalPlusScreen();
}

'''
    s = s[:a] + replacement + s[b:]
    # Keep the existing Today / All Time report unchanged; add a new period view.
    report_anchor = "        return ListView(key: const PageStorageKey('reports-scroll'), padding: const EdgeInsets.all(16), children: ["
    report_action = report_anchor + '''
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const FinanceReportScreen())),
            icon: const Icon(Icons.date_range_outlined),
            label: const Text('Laporan Periode & Ekspor CSV')),
          const SizedBox(height: 14),'''
    s = replace_once(s, report_anchor, report_action, 'report period action')
    s = s.replace("title: 'Catatan & Tugas', subtitle: 'Checklist kegiatan toko'",
                  "title: 'Catatan & Tugas', subtitle: 'Edit, kategori, tenggat dan bagikan'", 1)
    s = s.replace("title: 'Pulsa & Transaksi Digital', subtitle: 'Catat paket data, top up, admin'",
                  "title: 'Pulsa & Transaksi Digital', subtitle: 'Status, nomor referensi dan riwayat'", 1)
    return s

def patch_cash(s):
    s = replace_once(s, "import '../core/database.dart';",
        "import '../core/database.dart';\nimport 'store_finance_plus.dart';", 'cash imports')
    anchor = "    appBar: AppBar(title: const Text('Dompet Kas Toko'), actions: ["
    addition = anchor + '''
      IconButton(tooltip: 'Analisis kas & ekspor CSV',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const CashInsightsScreen())),
        icon: const Icon(Icons.assessment_outlined)),'''
    return replace_once(s, anchor, addition, 'cash report action')

def patch_inventory(s):
    s = replace_once(s, "import 'barcode_scanner.dart';",
        "import 'barcode_scanner.dart';\nimport 'store_finance_plus.dart';", 'inventory import')
    anchor = "          Row(children: [\n            Expanded(child: SearchBox(hint: 'Cari produk / barcode...',"
    addition = '''          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const InventoryInsightScreen())),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Insight Stok, Margin & Ekspor CSV')),
          const SizedBox(height: 12),
'''
    return replace_once(s, anchor, addition + anchor, 'inventory report button')

def patch_pubspec(s):
    return replace_once(s, VERSION_OLD, VERSION_NEW, 'pubspec version')

def patch_workflow(s):
    s = replace_once(s, 'AGAN-PONSEL-v1.7.0-Build27-APK',
        'AGAN-PONSEL-v1.8.0-Build28-APK', 'artifact name')
    anchor = '      - name: Analyze Flutter code'
    addition = '''      - name: Check Build28 notes, finance and digital SQLite
        run: |
          python3 scripts/check_build28.py
          python3 scripts/smoke_operations_v15.py

'''
    s = replace_once(s, anchor, addition + anchor, 'new smoke')
    return replace_once(s, 'test/build27_restock_test.dart',
        'test/build27_restock_test.dart test/build28_store_plus_test.dart',
        'Build28 unit test')

def patch_legacy(s):
    # Existing regression checks may reference the current version exactly.
    # They should still validate previous features in the next version.
    s = s.replace("'databaseVersion': 14", "'databaseVersion': 15")
    s = s.replace("'databaseVersion':\\s*14\\b", "'databaseVersion':\\s*15\\b")
    s = s.replace("version: 14", "version: 15")
    s = s.replace(r'version:\s*14\s*,',r'version:\s*15\s*,')
    s = s.replace('version: 1.7.0+27', 'version: 1.8.0+28')
    s = s.replace('AGAN-PONSEL-v1.7.0-Build27-APK', 'AGAN-PONSEL-v1.8.0-Build28-APK')
    s = s.replace('range(4,15)', 'range(4,16)')
    return s

scripts = [
    'scripts/check_build24.py','scripts/check_build25.py',
    'scripts/check_build26.py','scripts/check_build27.py',
    'scripts/smoke_expenses_v13.py','scripts/smoke_budget_backup.py',
    'scripts/smoke_restock_v14.py',
]
patches = {
    'lib/core/database.dart':patch_database,
    'lib/services/backup_service.dart':patch_backup,
    'lib/screens/others.dart':patch_others,
    'lib/screens/cash_screen.dart':patch_cash,
    'lib/screens/inventory.dart':patch_inventory,
    'pubspec.yaml':patch_pubspec,
    '.github/workflows/build-apk.yml':patch_workflow,
}
for f in scripts: patches[f]=patch_legacy

existing_version = (ROOT/'pubspec.yaml').read_text()
if VERSION_NEW in existing_version:
    print('Build28 already installed; no files changed')
    raise SystemExit(0)
if VERSION_OLD not in existing_version:
    raise SystemExit('Build28 requires completed Build27 (version: 1.7.0+27).')

required_files = [
    'lib/screens/store_notes.dart','lib/screens/digital_plus.dart',
    'lib/screens/store_finance_plus.dart','lib/services/store_plus_service.dart',
    'scripts/check_build28.py','scripts/smoke_operations_v15.py',
    'test/build28_store_plus_test.dart',
]
for f in required_files + list(patches):
    if not (ROOT/f).exists():
        raise SystemExit(f'Missing {f}: unzip Build28 package into correct repo first.')

planned = {}
for path, fn in patches.items():
    current = (ROOT/path).read_text()
    try:
        planned[path]=fn(current)
    except Exception as e:
        raise SystemExit(f'PATCH STOPPED on {path}: {e}') from e

for path, changed in planned.items():
    f=ROOT/path
    if f.read_text()!=changed:
        f.write_text(changed)
        print('UPDATED', path)
print('Build28 applied. Your on-device SQLite data has NOT been touched.')
