"""Smoke migration 8->9, sample payments, backup table order, without Flutter SDK."""
import re
import sqlite3
from pathlib import Path

root = Path(__file__).resolve().parent.parent
code = (root / 'lib/core/database.dart').read_text()
match = re.search(r"CREATE TABLE IF NOT EXISTS receivable_items\((.*?)\)'''", code, flags=re.S)
assert match, 'Missing receivable_items table in v9 migration'
schema = 'CREATE TABLE IF NOT EXISTS receivable_items(' + match.group(1) + ')'
assert 'if (oldVersion < 9)' in code
db_schema = re.search(r'\bversion:\s*(\d+)\s*,', code)
assert db_schema and int(db_schema.group(1)) >= 9, 'Database must support migration v9'

con = sqlite3.connect(':memory:')
con.execute('PRAGMA foreign_keys=ON')
con.execute('''CREATE TABLE receivables(
 id INTEGER PRIMARY KEY, customer_name TEXT, phone TEXT, description TEXT,
 amount INTEGER, due_date TEXT, created_at TEXT, notes TEXT)''')
con.execute('''CREATE TABLE receivable_payments(
 id INTEGER PRIMARY KEY, receivable_id INTEGER, amount INTEGER,
 method TEXT, paid_at TEXT, note TEXT,
 FOREIGN KEY(receivable_id) REFERENCES receivables(id))''')
con.execute('''INSERT INTO receivables VALUES(1,'Budi','08123','Charger',80000,
 '2026-11-01','2026-10-19','')''')
con.execute("INSERT INTO receivable_payments VALUES(1,1,20000,'Tunai','2026-10-19','DP')")
con.execute(schema)
con.execute(schema) # Can migrate more than once without wiping existing records.
con.execute('''INSERT INTO receivable_items(
 receivable_id,description,qty,unit_price,total,sort_order)
 VALUES(1,'Charger',2,25000,50000,0)''')
con.execute('''INSERT INTO receivable_items(
 receivable_id,description,qty,unit_price,total,sort_order)
 VALUES(1,'Kabel',3,10000,30000,1)''')
assert con.execute('SELECT SUM(total) FROM receivable_items').fetchone()[0] == 80000
assert con.execute('SELECT SUM(amount) FROM receivable_payments').fetchone()[0] == 20000
assert con.execute('SELECT amount FROM receivables').fetchone()[0] == 80000
# Old backup documents can omit the new line-item table and still be accepted.
backup = (root / 'lib/services/backup_service.dart').read_text()
assert "'receivable_items'" in backup
backup_schema = re.search(r"'databaseVersion':\s*(\d+)", backup)
assert backup_schema and int(backup_schema.group(1)) >= 9, 'Backup must support migration v9'
supported_versions = re.search(
    r"\[([0-9,\s]+)\]\.contains\(payload\['databaseVersion'\]\)", backup)
assert supported_versions, 'Backup must declare allowed legacy database versions'
supported = {int(value.strip()) for value in supported_versions.group(1).split(',')}
assert set(range(4, 10)).issubset(supported), 'Missing legacy version in restore whitelist'
assert backup.index("'receivables'") < backup.index("'receivable_items'")
print('OK: SQLite v9 item detail migration, legacy debt and payments preserved')
