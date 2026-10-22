"""Tests v9->v10 migration for receipt event logging without a Flutter SDK."""
from pathlib import Path
import re
import sqlite3

root = Path(__file__).resolve().parent.parent
code = (root / 'lib/core/database.dart').read_text()
db_schema = re.search(r'\bversion:\s*(\d+)\s*,', code)
assert db_schema and int(db_schema.group(1)) >= 10, 'Database must support migration v10'
assert 'if (oldVersion < 10)' in code
match = re.search(r"CREATE TABLE IF NOT EXISTS receivable_receipt_events\((.*?)\)'''", code, re.S)
assert match, 'Receipt events table migration missing'
schema = 'CREATE TABLE IF NOT EXISTS receivable_receipt_events(' + match.group(1) + ')'
con = sqlite3.connect(':memory:')
con.execute('PRAGMA foreign_keys = ON')
con.execute('CREATE TABLE receivables (id INTEGER PRIMARY KEY, customer_name TEXT, amount INTEGER)')
con.execute("INSERT INTO receivables VALUES (7, 'Budi', 80000)")
con.execute(schema)
con.execute(schema)  # idempotent
con.execute("INSERT INTO receivable_receipt_events (receivable_id,action,destination,template,created_at) VALUES (7,'print_dispatched','','orbit','2026-10-19T12:00:00')")
assert con.execute('SELECT amount FROM receivables WHERE id=7').fetchone()[0] == 80000
assert con.execute('SELECT COUNT(*) FROM receivable_receipt_events').fetchone()[0] == 1
backup = (root / 'lib/services/backup_service.dart').read_text()
assert "'receivable_receipt_events'" in backup
backup_schema = re.search(r"'databaseVersion':\s*(\d+)", backup)
assert backup_schema and int(backup_schema.group(1)) >= 10, 'Backup must support migration v10'
# dart format can wrap the list, `.contains(` call and its argument.
# Preserve the assertion on *actual* restore-compatible database versions.
supported_versions = re.search(
    r"\[\s*([0-9,\s]+?)\s*\]\s*\.contains\s*\(\s*"
    r"payload\s*\[\s*'databaseVersion'\s*\]\s*,?\s*\)",
    backup,
    flags=re.S,
)
assert supported_versions, 'Backup must declare allowed legacy database versions'
supported = {int(value.strip()) for value in supported_versions.group(1).split(',') if value.strip()}
assert set(range(4, int(db_schema.group(1)) + 1)).issubset(supported), 'Missing legacy/current version in restore whitelist'
assert backup.index("'receivable_items'") < backup.index("'receivable_receipt_events'")
assert "'receivable_receipt_template'" in backup
print('OK: SQLite v10 receipt log, preservation and backup compatibility')
