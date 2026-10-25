"""Exercise Build28 patcher on a synthetic Build27 tree, no Flutter required."""
from pathlib import Path
import tempfile, subprocess, sys, shutil

origin = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp)
    for source in origin.rglob('*'):
        if source.is_file() and '__pycache__' not in source.parts:
            dest = p / source.relative_to(origin)
            dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,dest)
    fixture={
      'lib/core/database.dart': '''import 'package:sqflite/sqflite.dart';
class AppDatabase {
  void begin(DatabaseExecutor db) async {
    version: 14,
        await _createRestockV14(db);
        await _createRestockV14(db);
        if (oldVersion < 14) {
          await _createRestockV14(db);
        }
    final fees = await aggregate('digital_transactions', 'fee');
  }
  // AGAN_PONSEL_RESTOCK_V14
  static Future<void> _createRestockV14(DatabaseExecutor db) async {}
  /// v13: richer expense details
}
''',
      'lib/services/backup_service.dart': """class BackupService {
  static const tables = [
    'digital_transactions',
    'suppliers', 'restock_orders', 'restock_order_items',
  ];
  final m={'databaseVersion': 14};
  bool read(Map payload) => ![4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14].contains(payload['databaseVersion']);
}
""",
      'lib/screens/others.dart': """import 'restock_center.dart';
class DigitalScreen extends StatefulWidget {
}
class ReportsScreen extends StatefulWidget {}
        return ListView(key: const PageStorageKey('reports-scroll'), padding: const EdgeInsets.all(16), children: [
class _ReportCard extends StatelessWidget {}
      title: 'Catatan & Tugas', subtitle: 'Checklist kegiatan toko',
      title: 'Pulsa & Transaksi Digital', subtitle: 'Catat paket data, top up, admin',
""",
      'lib/screens/cash_screen.dart': """import '../core/database.dart';
class CashScreen {
    appBar: AppBar(title: const Text('Dompet Kas Toko'), actions: [
    ]),
}
""",
      'lib/screens/inventory.dart': """import 'barcode_scanner.dart';
class InventoryScreen {
          Row(children: [
            Expanded(child: SearchBox(hint: 'Cari produk / barcode...',
          )]),
}
""",
      'pubspec.yaml': 'version: 1.7.0+27\n',
      '.github/workflows/build-apk.yml': """name: Build
          name: AGAN-PONSEL-v1.7.0-Build27-APK
      - name: Analyze Flutter code
        run: flutter analyze
        run: flutter test test/build27_restock_test.dart
""",
    }
    for path, text in fixture.items():
        dest=p/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text)
    for f in ['check_build24.py','check_build25.py','check_build26.py',
              'check_build27.py','smoke_expenses_v13.py','smoke_budget_backup.py',
              'smoke_restock_v14.py']:
        (p/'scripts'/f).write_text("version: 14\n'databaseVersion': 14\n"
            'version: 1.7.0+27\nAGAN-PONSEL-v1.7.0-Build27-APK\n')
    def cmd(script):
        r = subprocess.run([sys.executable,script], cwd=p,
            capture_output=True,text=True)
        if r.returncode:
            raise AssertionError(f'{script} FAILED\n{r.stdout}\n{r.stderr}')
        return r.stdout
    output=cmd('scripts/apply_build28.py')
    assert 'UPDATED lib/core/database.dart' in output
    assert 'UPDATED .github/workflows/build-apk.yml' in output
    cmd('scripts/smoke_operations_v15.py')
    assert 'already installed' in cmd('scripts/apply_build28.py')
    assert "'digital_events'" in (p/'lib/services/backup_service.dart').read_text()
    assert 'version: 1.8.0+28' in (p/'pubspec.yaml').read_text()
    print('OK: Build28 fixture patched, SQLite smoke passed, second run idempotent')
