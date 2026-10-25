"""Build28 static integration guard. Does not substitute for flutter analyze/test."""
from pathlib import Path
import re

checks = {
  'lib/core/database.dart': [
    'version: 15', 'if (oldVersion < 15)', '_createOperationsV15',
    'digital_events', 'digitalFields', 'noteFields',
  ],
  'lib/services/store_plus_service.dart': [
    'class StorePlusService', 'saveNote', 'updateDigital',
    'digitalEvents', 'cashStats', 'inventoryStats', 'report(',
  ],
  'lib/screens/store_notes.dart': [
    'class StoreNotesScreen', 'edit(', 'SharePlus.instance.share',
    'Tenggat', 'Sematkan', 'ChoiceChip', 'Prioritas',
  ],
  'lib/screens/store_finance_plus.dart': [
    'class CashInsightsScreen', 'class FinanceReportScreen',
    'class InventoryInsightScreen', 'Ekspor Buku Kas CSV',
    'Ekspor Persediaan CSV', 'showDateRangePicker',
  ],
  'lib/screens/digital_plus.dart': [
    'class DigitalPlusScreen', 'class _DigitalDetail',
    'StorePlusService.updateDigital', 'referensi',
  ],
  'lib/screens/others.dart': [
    "import 'digital_plus.dart';", "import 'store_finance_plus.dart';",
    'class DigitalScreen extends StatelessWidget',
    'class ReportsScreen extends StatefulWidget',
    'RestockCenterScreen', 'StoreNotesScreen',
  ],
  'lib/screens/cash_screen.dart':['CashInsightsScreen'],
  'lib/screens/inventory.dart':['InventoryInsightScreen'],
  'lib/services/backup_service.dart': [
    "'digital_events'", "'databaseVersion': 15",
    "'expense_budget_settings'", "'restock_order_items'",
  ],
  'pubspec.yaml':['version: 1.8.0+28', 'shared_preferences_android: 2.4.28'],
  '.github/workflows/build-apk.yml':[
    'AGAN-PONSEL-v1.8.0-Build28-APK',
    'scripts/smoke_operations_v15.py',
    'test/build28_store_plus_test.dart',
    'Test WhatsApp Agent Webhook',
  ],
}
for path, markers in checks.items():
    text = Path(path).read_text()
    for marker in markers:
        assert marker in text, f'{path} missing {marker!r}'

db = Path('lib/core/database.dart').read_text()
assert db.count('await _createOperationsV15(db);') == 3
assert re.search(r'\bversion:\s*15\s*,', db)
print('OK: Build28 Catatan, Kas, Laporan, Digital, Produk and Build27 integrations')
