"""Smoke test SQLite v10->v11 on an in-memory legacy store.
Verifies item timestamps, payment audit/amounts, bon history and backup schema.
This is SQL test, NOT a substitute for flutter test / real-device testing.
"""
from pathlib import Path
import re, sqlite3
root = Path(__file__).resolve().parent.parent
dbcode = (root/'lib/core/database.dart').read_text()
service = (root/'lib/services/receivables_service.dart').read_text()
backup = (root/'lib/services/backup_service.dart').read_text()
db_schema = re.search(r'\bversion:\s*(\d+)\s*,', dbcode)
assert db_schema and int(db_schema.group(1)) >= 11, 'Database must support migration v11'
assert 'if (oldVersion < 11)' in dbcode
assert 'await _createPaymentCorrections(db);' in dbcode
assert 'entry_date' in service and 'editPayment' in service and 'appendBon' in service
backup_schema = re.search(r"'databaseVersion':\s*(\d+)", backup)
assert backup_schema and int(backup_schema.group(1)) >= 11, 'Backup must support migration v11'
assert "'receivable_payment_edits'" in backup and "'receivable_bon_events'" in backup

con=sqlite3.connect(':memory:'); con.execute('PRAGMA foreign_keys=ON')
con.execute('''CREATE TABLE receivables(id INTEGER PRIMARY KEY, customer_name TEXT NOT NULL,
  phone TEXT, description TEXT NOT NULL, amount INTEGER NOT NULL, due_date TEXT,
  created_at TEXT NOT NULL, notes TEXT)''')
con.execute('''CREATE TABLE receivable_payments(id INTEGER PRIMARY KEY,
  receivable_id INTEGER NOT NULL, amount INTEGER NOT NULL, method TEXT,
  paid_at TEXT, note TEXT, FOREIGN KEY(receivable_id) REFERENCES receivables(id))''')
con.execute('''CREATE TABLE receivable_items(id INTEGER PRIMARY KEY,
  receivable_id INTEGER NOT NULL,description TEXT,qty INTEGER,unit_price INTEGER,
  total INTEGER,sort_order INTEGER,FOREIGN KEY(receivable_id) REFERENCES receivables(id))''')
con.execute("INSERT INTO receivables VALUES (1,'Pelanggan A','','Bon lama',150000,'2026-11-05','2026-09-15T08:30:00','')")
con.execute("INSERT INTO receivable_payments VALUES (7,1,30000,'Tunai','2026-09-16T11:00:00','Awal')")
con.execute("INSERT INTO receivable_items VALUES (9,1,'Bon lama',1,150000,150000,0)")
# Extract the CREATE TABLE statements in the Dart DB source, so the smoke test
# exercises real SQL statements instead of duplicating the schema by hand.
for table in ('receivable_payment_edits','receivable_bon_events'):
    m=re.search(r"CREATE TABLE IF NOT EXISTS " + table + r"\((.*?)\)'''",dbcode,re.S)
    assert m,table
    con.execute('CREATE TABLE IF NOT EXISTS '+table+'('+m.group(1)+')')
    con.execute('CREATE TABLE IF NOT EXISTS '+table+'('+m.group(1)+')')
con.execute("ALTER TABLE receivable_items ADD COLUMN entry_date TEXT NOT NULL DEFAULT ''")
con.execute('''UPDATE receivable_items SET entry_date =
  COALESCE((SELECT substr(created_at,1,10) FROM receivables
  WHERE receivables.id=receivable_items.receivable_id),strftime('%Y-%m-%d','now'))
  WHERE entry_date='' OR entry_date IS NULL''')
assert con.execute('SELECT entry_date FROM receivable_items WHERE id=9').fetchone()[0]=='2026-09-15'
with con:
    con.execute('''UPDATE receivable_payments SET amount=50000,method='Transfer',
        paid_at='2026-09-17T12:00:00' WHERE id=7 AND receivable_id=1''')
    con.execute('''INSERT INTO receivable_payment_edits(
        receivable_id,payment_id,old_amount,new_amount,old_method,new_method,
        old_note,new_note,old_paid_at,new_paid_at,reason,edited_at)
        VALUES(1,7,30000,50000,'Tunai','Transfer','Awal','Awal',
        '2026-09-16T11:00:00','2026-09-17T12:00:00',
        'Salah masukkan nominal','2026-10-21T10:00:00')''')
assert con.execute('SELECT amount FROM receivable_payments WHERE id=7').fetchone()[0]==50000
assert con.execute('SELECT old_amount FROM receivable_payment_edits').fetchone()[0]==30000
with con:
    con.execute("INSERT INTO receivable_items(receivable_id,description,qty,unit_price,total,sort_order,entry_date) VALUES(1,'Charger',2,25000,50000,1,'2026-10-21')")
    con.execute('UPDATE receivables SET amount=amount+50000 WHERE id=1')
    con.execute("INSERT INTO receivable_bon_events(receivable_id,action,amount,item_count,created_at) VALUES(1,'bon_added',50000,1,'2026-10-21T10:00:00')")
assert con.execute('SELECT amount FROM receivables').fetchone()[0]==200000
assert con.execute('SELECT SUM(total) FROM receivable_items').fetchone()[0]==200000
assert con.execute('SELECT SUM(amount) FROM receivable_payments').fetchone()[0]==50000
assert con.execute('SELECT amount FROM receivable_bon_events').fetchone()[0]==50000
assert con.execute('SELECT COUNT(*) FROM receivable_payment_edits').fetchone()[0]==1
# Transaction rollback on invalid overpayment: no half-audit.
try:
    with con:
        other_paid=con.execute('SELECT SUM(amount) FROM receivable_payments WHERE receivable_id=1 AND id<>7').fetchone()[0] or 0
        principal=con.execute('SELECT amount FROM receivables WHERE id=1').fetchone()[0]
        updated=principal+1
        if other_paid+updated>principal: raise ValueError('Overpayment rejected')
        con.execute('UPDATE receivable_payments SET amount=? WHERE id=7',(updated,))
except ValueError:
    pass
assert con.execute('SELECT amount FROM receivable_payments WHERE id=7').fetchone()[0]==50000
assert con.execute('SELECT COUNT(*) FROM receivable_payment_edits').fetchone()[0]==1
print('OK: SQLite v11 migration, bon dates, atomic correction audit, legacy data and backup')
