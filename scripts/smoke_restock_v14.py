"""SQL regression for AGAN PONSEL Build27 supplier + restock (stdlib only).

Exercises DDL extracted from Flutter source; does not claim Flutter/Android
compilation or printer/WhatsApp device verification.
"""
from pathlib import Path
import re
from backup_compat_check import assert_backup_versions
import sqlite3

root = Path(__file__).resolve().parent.parent
code = (root/'lib/core/database.dart').read_text()
backup = (root/'lib/services/backup_service.dart').read_text()
found = re.search(r'\bversion:\s*(\d+)\s*,', code)
assert found and int(found.group(1)) >= 14, 'SQLite schema must support v14+'
assert 'if (oldVersion < 14)' in code
assert code.count('await _createRestockV14(db);') == 3
for name in ['suppliers','restock_orders','restock_order_items']:
    assert f"'{name}'" in backup
assert backup.index("'suppliers'") < backup.index("'restock_orders'") < backup.index("'restock_order_items'")

assert_backup_versions(backup, minimum=14, current=int(found.group(1)))

section = code.split('static Future<void> _createRestockV14',1)[1].split('  /// v13:',1)[0]
tables = re.findall(r"db\.execute\('''(CREATE TABLE IF NOT EXISTS .*?)'''\)", section, flags=re.S)
assert len(tables)==3, 'Expected three new SQLite tables extracted from Dart'

con=sqlite3.connect(':memory:')
con.execute('PRAGMA foreign_keys=ON')
con.execute('''CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT NOT NULL,
 stock INTEGER NOT NULL, min_stock INTEGER NOT NULL, cost INTEGER NOT NULL)''')
con.execute('''CREATE TABLE stock_movements(
 id INTEGER PRIMARY KEY, product_id INTEGER, product_name TEXT,
 delta INTEGER, note TEXT, created_at TEXT)''')
con.execute("INSERT INTO products VALUES(1,'Charger',2,5,25000)")
con.execute("INSERT INTO products VALUES(2,'Kabel',3,4,10000)")
for sql in tables:
    con.execute(sql)
for sql in tables:
    con.execute(sql) # repeat onOpen = safe
con.execute("INSERT INTO suppliers(name,phone,address,note,created_at,updated_at) VALUES('Supplier A','0812345','','','2026-10-24','2026-10-24')")
con.execute("INSERT INTO restock_orders(supplier_id,status,notes,estimated_total,created_at,received_at) VALUES(1,'draft','',95000,'2026-10-24','')")
con.execute("INSERT INTO restock_order_items(order_id,product_id,product_name,qty,unit_cost) VALUES(1,1,'Charger',3,25000)")
con.execute("INSERT INTO restock_order_items(order_id,product_id,product_name,qty,unit_cost) VALUES(1,2,'Kabel',2,10000)")
assert con.execute("SELECT SUM(qty*unit_cost) FROM restock_order_items").fetchone()[0]==95000
assert con.execute('SELECT SUM(stock) FROM products').fetchone()[0]==5  # draft unchanged

# Explicit confirmation updates stock + movement + status in ONE transaction.
def receive(order_id):
    with con:
        row=con.execute('SELECT status FROM restock_orders WHERE id=?',(order_id,)).fetchone()
        if row is None or row[0]!='draft': raise ValueError('not draft')
        items=con.execute('SELECT product_id,product_name,qty FROM restock_order_items WHERE order_id=?',(order_id,)).fetchall()
        if not items: raise ValueError('empty')
        for product_id,_,_ in items:
            if not con.execute('SELECT 1 FROM products WHERE id=?',(product_id,)).fetchone():
                raise ValueError('deleted product')
        for product_id,name,qty in items:
            con.execute('UPDATE products SET stock=stock+? WHERE id=?',(qty,product_id))
            con.execute('INSERT INTO stock_movements(product_id,product_name,delta,note,created_at) VALUES(?,?,?,?,?)',
                        (product_id,name,qty,f'Restock #{order_id} • barang diterima','2026-10-24'))
        con.execute("UPDATE restock_orders SET status='received',received_at='2026-10-24' WHERE id=? AND status='draft'",(order_id,))
receive(1)
assert con.execute('SELECT stock FROM products WHERE id=1').fetchone()[0]==5
assert con.execute('SELECT stock FROM products WHERE id=2').fetchone()[0]==5
assert con.execute('SELECT SUM(delta) FROM stock_movements').fetchone()[0]==5
try:
    receive(1)
except ValueError:
    pass
else:
    raise AssertionError('second stock receipt should be rejected')
assert con.execute('SELECT SUM(delta) FROM stock_movements').fetchone()[0]==5
# Missing item blocks the entire order, with zero stock changes.
con.execute("INSERT INTO restock_orders(id,status,notes,estimated_total,created_at,received_at) VALUES(2,'draft','',1000,'2026-10-24','')")
con.execute("INSERT INTO restock_order_items(order_id,product_id,product_name,qty,unit_cost) VALUES(2,99,'Hilang',1,1000)")
con.commit()
try:
    receive(2)
except ValueError:
    pass
else:
    raise AssertionError('deleted product should prevent receipt')
assert con.execute('SELECT SUM(delta) FROM stock_movements').fetchone()[0]==5
assert con.execute('SELECT status FROM restock_orders WHERE id=2').fetchone()[0]=='draft'
print('OK: SQLite v14 schema, legacy backups, draft unchanged, atomic receive, no duplicate receipt')
