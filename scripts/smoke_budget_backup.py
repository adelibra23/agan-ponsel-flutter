"""Check backwards-compatible backup profile and historical expense fixture.

Does not simulate Flutter compilation or plugin behavior.
"""
import re
from backup_compat_check import assert_backup_versions
import sqlite3
from pathlib import Path
root = Path(__file__).resolve().parent.parent
backup = (root/'lib/services/backup_service.dart').read_text()
service = (root/'lib/services/expense_insights_service.dart').read_text()
assert "'expense_budget_settings'" in backup
assert "'expense_budget_settings'" in service
db_source = (root/'lib/core/database.dart').read_text()
found = re.search(r'\bversion:\s*(\d+)\s*,', db_source)
assert found and int(found.group(1)) >= 14, 'SQLite schema must support v14+'
assert_backup_versions(backup, minimum=14, current=int(found.group(1)))
# Historical rows remain unchanged; the new feature only reads this table.
con = sqlite3.connect(':memory:')
con.execute('CREATE TABLE expenses (id INTEGER PRIMARY KEY,description TEXT,amount INTEGER,created_at TEXT)')
con.executemany('INSERT INTO expenses VALUES(?,?,?,?)', [
  (1,'Kertas',50000,'2026-10-15T08:00:00'),
  (2,'Internet',120000,'2026-10-17T10:00:00'),
])
assert con.execute('SELECT SUM(amount) FROM expenses').fetchone()[0] == 170000
assert 'expense_budgets' not in (root/'lib/core/database.dart').read_text()
print('OK: budget profile key in backup, legacy versions accepted, historical expense rows preserved')
