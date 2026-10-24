"""Minimal guard for applying Build27 restore-version CI hotfix."""
from pathlib import Path
import re
from backup_compat_check import assert_backup_versions

root = Path(__file__).resolve().parent.parent
pubspec = (root/'pubspec.yaml').read_text()
assert re.search(r'(?m)^version:\s*1\.7\.0\+27\s*$', pubspec), (
    'Hotfix ini hanya untuk AGAN PONSEL v1.7.0+27; jangan terapkan ke versi lain.')
source = (root/'lib/core/database.dart').read_text()
match = re.search(r'\bversion:\s*(\d+)\s*,', source)
assert match and int(match.group(1)) == 14, 'Build27 harus memakai SQLite v14'
backup = (root/'lib/services/backup_service.dart').read_text()
allowed = assert_backup_versions(backup, minimum=14, current=14)
assert all(name in backup for name in ("'suppliers'", "'restock_orders'", "'restock_order_items'"))
for name in ('smoke_receivable_details.py','smoke_receipt_v10.py',
             'smoke_budget_backup.py','smoke_restock_v14.py'):
    text = (root/'scripts'/name).read_text()
    assert 'from backup_compat_check import assert_backup_versions' in text, (
        f'{name} belum memakai parser yang tahan dart format')
print('OK: Build27 v14, backup v4-v14, empat tes CI terhubung; tidak mengubah database')
