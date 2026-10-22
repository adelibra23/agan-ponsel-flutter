"""SQLite v12 fixture: old expenses preserved, categories and audit are additive.
Run with Python stdlib only, no Flutter dependency.
"""
import sqlite3
import re
from pathlib import Path

con=sqlite3.connect(':memory:')
con.row_factory=sqlite3.Row
con.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, amount INTEGER NOT NULL, created_at TEXT NOT NULL)')
con.execute('INSERT INTO expenses(description,amount,created_at) VALUES (?,?,?)',('Kabel charger',45000,'2026-09-11T10:00:00'))
assert con.execute('SELECT SUM(amount) FROM expenses').fetchone()[0]==45000
dart = Path('lib/core/database.dart').read_text()
section = dart.split('static Future<void> _createExpensesV12', 1)[1].split('  // v11:', 1)[0]
actual_ddl = re.findall(r"db\.execute\('''(CREATE TABLE IF NOT EXISTS .+?)'''\)", section, re.S)
assert len(actual_ddl) == 2, 'Dart table DDL not found'
for sql in actual_ddl: con.execute(sql)

fields={'category_id':'INTEGER','payment_method':"TEXT NOT NULL DEFAULT 'Tunai'",'note':"TEXT NOT NULL DEFAULT ''",'updated_at':"TEXT NOT NULL DEFAULT ''"}
for name,definition in fields.items():
 if name not in {x['name'] for x in con.execute('PRAGMA table_info(expenses)')}:
  con.execute(f'ALTER TABLE expenses ADD COLUMN {name} {definition}')
for name in ['Lainnya','Operasional','Sparepart','Transportasi']:
 con.execute('INSERT OR IGNORE INTO expense_categories(name,archived,created_at) VALUES (?,0,?)',(name,'2026-10-23'))
old=con.execute('SELECT * FROM expenses WHERE id=1').fetchone()
assert old['amount']==45000 and old['payment_method']=='Tunai' and old['created_at']=='2026-09-11T10:00:00'
category=con.execute('SELECT id FROM expense_categories WHERE name=?',('Sparepart',)).fetchone()['id']
with con:
 con.execute('UPDATE expenses SET amount=?,category_id=?,created_at=?,note=? WHERE id=?',(55000,category,'2026-09-12T14:20:00','Salah input',1))
 con.execute('INSERT INTO expense_audit(expense_id,action,old_amount,new_amount,reason,occurred_at) VALUES (?,?,?,?,?,?)',(1,'edit',45000,55000,'Salah nominal','2026-10-23'))
assert con.execute('SELECT SUM(amount) FROM expenses').fetchone()[0]==55000
assert con.execute('SELECT count(*) FROM expense_audit WHERE expense_id=1').fetchone()[0]==1
con.execute('UPDATE expense_categories SET archived=1 WHERE id=?',(category,))
assert con.execute('SELECT name FROM expense_categories WHERE id=?',(category,)).fetchone()[0]=='Sparepart'
with con:
 con.execute('INSERT INTO expense_audit(expense_id,action,old_amount,new_amount,reason,occurred_at) VALUES (?,?,?,?,?,?)',(1,'delete',55000,0,'Duplikat','2026-10-23'))
 con.execute('DELETE FROM expenses WHERE id=1')
assert con.execute('SELECT COALESCE(SUM(amount),0) FROM expenses').fetchone()[0]==0
assert con.execute('SELECT count(*) FROM expense_audit').fetchone()[0]==2
print('OK: SQLite v12 expense migration, correction, archive, audit, cash sum')
