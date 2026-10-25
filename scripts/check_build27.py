"""Regression guard for source integration with Build26 (no Flutter SDK)."""
from pathlib import Path
import re

required={
 'lib/core/database.dart': ['version: 15', '_createRestockV14', 'if (oldVersion < 14)',
   'restock_order_items', 'suppliers', 'stock_movements'],
 'lib/services/restock_service.dart': ['class RestockService', 'suggestedQty',
   'createOrder', 'receiveOrder', 'cancelOrder', 'db.transaction', 'stock_movements'],
 'lib/screens/restock_center.dart': ['class RestockCenterScreen',
   'class RestockEditorScreen', 'class SupplierEditorScreen',
   'Konfirmasi Barang Diterima', 'RestockService.receiveOrder'],
 'lib/screens/others.dart': ["import 'restock_center.dart';", "title: 'Restock & Supplier'",
   'DriveBackupSettingsScreen', 'DebtAlarmSettingsScreen'],
 'lib/services/backup_service.dart': ["'databaseVersion': 15",
   "'suppliers'", "'restock_orders'", "'restock_order_items'",
   "'expense_budget_settings'"],
 'pubspec.yaml':['version: 1.8.0+28', 'shared_preferences_android: 2.4.28'],
 '.github/workflows/build-apk.yml': ['AGAN-PONSEL-v1.8.0-Build28-APK',
   'test/build27_restock_test.dart', 'scripts/smoke_restock_v14.py',
   'test/build26_insights_test.dart', 'Test WhatsApp Agent Webhook'],
}
for path,markers in required.items():
    target=Path(path)
    assert target.exists(),f'{path} missing'
    source=target.read_text()
    for marker in markers:
        assert marker in source, f'{path}: missing {marker}'
db=Path('lib/core/database.dart').read_text()
assert len(re.findall(r'await _createRestockV14\(db\);',db))==3
assert Path('lib/screens/expenses_v2.dart').exists(), 'Build25 expenses lost'
assert Path('lib/screens/expense_insights.dart').exists(), 'Build26 insights lost'
print('OK: Build27 Restock & Supplier integrated, Build21-26 features preserved')
