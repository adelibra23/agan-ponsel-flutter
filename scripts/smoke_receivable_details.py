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
assert 'version: 9' in code

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
assert "'databaseVersion': 9" in backup
assert "[4, 5, 6, 7, 8, 9]" in backup
assert backup.index("'receivables'") < backup.index("'receivable_items'")
print('OK: SQLite v9 item detail migration, legacy debt and payments preserved')
