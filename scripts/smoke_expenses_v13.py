"""SQLite v13 expense migration smoke test; no Flutter SDK required.

Exercise real Dart SQL field declarations with a v12-style preexisting store.
Tests amount, category and audit preservation, idempotence, and backfills.
"""
from pathlib import Path
import re
import sqlite3

root = Path(__file__).resolve().parent.parent
source = (root / 'lib/core/database.dart').read_text()
service = (root / 'lib/services/expenses_service.dart').read_text()
backup = (root / 'lib/services/backup_service.dart').read_text()
assert 'version: 14' in source
assert 'if (oldVersion < 13)' in source
assert "'databaseVersion': 14" in backup
assert '10, 11, 12, 13' in backup
assert 'unitPrice' in service and 'colorValue' in service
assert 'UPDATE expenses SET unit_price=amount' in source

con = sqlite3.connect(':memory:')
con.row_factory = sqlite3.Row
con.execute('''CREATE TABLE expenses(id INTEGER PRIMARY KEY, description TEXT NOT NULL,
 amount INTEGER NOT NULL, created_at TEXT NOT NULL, category_id INTEGER,
 payment_method TEXT NOT NULL DEFAULT 'Tunai', note TEXT NOT NULL DEFAULT '',
 updated_at TEXT NOT NULL DEFAULT '')''')
con.execute('''CREATE TABLE expense_categories(id INTEGER PRIMARY KEY,
 name TEXT NOT NULL UNIQUE COLLATE NOCASE, archived INTEGER DEFAULT 0,
 created_at TEXT NOT NULL)''')
con.execute('''CREATE TABLE expense_audit(id INTEGER PRIMARY KEY,
 expense_id INTEGER NOT NULL, action TEXT, old_amount INTEGER,
 new_amount INTEGER, reason TEXT, snapshot TEXT, occurred_at TEXT)''')
con.execute("INSERT INTO expense_categories VALUES (2,'Sparepart',0,'2026-10-22')")
con.execute("INSERT INTO expenses VALUES (7,'LCD',75000,'2026-10-22T10:30:00',2,'Tunai','','')")
con.execute("INSERT INTO expense_audit VALUES (4,7,'create',0,75000,'awal','','2026-10-22')")

block = source.split('static Future<void> _createExpensesV13', 1)[1].split('  /// v12:',1)[0]
fields_exp = re.search(r'const expenseFields = <String, String>\{(.*?)\n    \};', block, re.S)
fields_cat = re.search(r'const categoryFields = <String, String>\{(.*?)\n    \};', block, re.S)
assert fields_exp and fields_cat

def parse_fields(fields):
    result = {}
    for raw in fields.group(1).splitlines():
        found = re.search(r"^\s*'([^']+)':\s*(.+),\s*$", raw)
        if not found:
            continue
        name, value = found.groups()
        if value.startswith('"') and value.endswith('"'):
            definition = value[1:-1]
        elif value.startswith("'") and value.endswith("'"):
            definition = value[1:-1]
        else:
            raise ValueError(raw)
        result[name] = definition
    return result

expense_additions = parse_fields(fields_exp)
category_additions = parse_fields(fields_cat)
assert set(expense_additions) == {'quantity','unit_price','merchant','reference_code'}
assert set(category_additions) == {'icon_key','color_value'}

def migrate():
    for table, fields in [('expenses',expense_additions),('expense_categories',category_additions)]:
        exists = {row['name'] for row in con.execute(f'PRAGMA table_info({table})')}
        for name, definition in fields.items():
            if name not in exists:
                con.execute(f'ALTER TABLE {table} ADD COLUMN {name} {definition}')
    con.execute('UPDATE expenses SET unit_price=amount WHERE unit_price=0 AND amount>0')

migrate(); migrate()
old = con.execute('SELECT * FROM expenses WHERE id=7').fetchone()
assert old['amount']==75000 and old['unit_price']==75000 and old['quantity']==1
assert old['created_at']=='2026-10-22T10:30:00'
assert old['merchant']=='' and old['reference_code']==''
assert con.execute('SELECT COUNT(*) FROM expense_audit').fetchone()[0]==1
assert con.execute('SELECT archived FROM expense_categories WHERE id=2').fetchone()[0]==0

# A new purchase: quantity 3 x unit price 25,000 = 75,000.
con.execute('''INSERT INTO expenses(description,amount,created_at,category_id,
 unit_price,quantity,merchant,reference_code) VALUES (?,?,?,?,?,?,?,?)''',
 ('Kertas HVS',75000,'2026-10-23T09:00:00',2,25000,3,'Supplier A','INV-025'))
assert con.execute('SELECT quantity*unit_price FROM expenses WHERE id=8').fetchone()[0]==75000
with con:
    con.execute('UPDATE expenses SET unit_price=20000,amount=60000 WHERE id=8')
    con.execute('''INSERT INTO expense_audit(expense_id,action,old_amount,new_amount,reason,occurred_at)
      VALUES (8,'edit',75000,60000,'Diskon supplier','2026-10-23')''')
assert con.execute('SELECT amount FROM expenses WHERE id=8').fetchone()[0]==60000
assert con.execute('SELECT COUNT(*) FROM expense_audit').fetchone()[0]==2
con.execute('UPDATE expense_categories SET icon_key=?,color_value=? WHERE id=2',
 ('shopping',4282348490))
assert con.execute('SELECT icon_key FROM expense_categories WHERE id=2').fetchone()[0]=='shopping'
migrate()
assert con.execute('SELECT icon_key,color_value FROM expense_categories WHERE id=2').fetchone()['color_value']==4282348490
assert con.execute('SELECT SUM(amount) FROM expenses').fetchone()[0]==135000
print('OK: SQLite v13 old expenses intact, amount=qty*unit price, category icons/colors, audit and backup')
