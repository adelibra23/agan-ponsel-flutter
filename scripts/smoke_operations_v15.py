"""SQLite v14->v15 additive migration fixture (stdlib only).

Extract the actual Dart column definitions and table DDL to validate
preservation of legacy notes/digital rows and transaction audit behavior.
This does not compile Flutter, test Android plugins, or certify APKs.
"""
from pathlib import Path
import re
import sqlite3

src = Path('lib/core/database.dart').read_text()
backup = Path('lib/services/backup_service.dart').read_text()
assert 'version: 15' in src and 'if (oldVersion < 15)' in src
assert "'databaseVersion': 15" in backup and "'digital_events'" in backup
assert backup.index("'digital_transactions'") < backup.index("'digital_events'")
whitelist = re.search(r"\[([0-9,\s]+)\]\s*\.\s*contains\s*\(\s*payload\s*\[\s*'databaseVersion'\s*\]\s*\)", backup, re.S)
assert whitelist, 'Restore compatibility list missing'
versions={int(x.strip()) for x in whitelist.group(1).split(',')}
assert set(range(4, 16)).issubset(versions)

block = src.split('static Future<void> _createOperationsV15', 1)[1].split('  // AGAN_PONSEL_RESTOCK_V14',1)[0]

def columns(key):
    match=re.search(r'const '+key+r' = <String, String>\{(.*?)\n    \};',block,re.S)
    assert match, key
    result={}
    for name,quote,definition in re.findall(r"'([^']+)':\s*(['\"])(.*?)\2\s*,",match.group(1)):
        result[name]=definition
    return result

note=columns('noteFields')
digital=columns('digitalFields')
assert set(note)=={'category','priority','due_at','pinned','updated_at'}
assert set(digital)=={'status','note','reference_code','payment_method'}

con=sqlite3.connect(':memory:')
con.row_factory=sqlite3.Row
con.execute('CREATE TABLE store_notes(id INTEGER PRIMARY KEY, text TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)')
con.execute('CREATE TABLE digital_transactions(id INTEGER PRIMARY KEY, operator TEXT NOT NULL, destination TEXT NOT NULL, nominal INTEGER NOT NULL, fee INTEGER NOT NULL, created_at TEXT NOT NULL)')
con.execute("INSERT INTO store_notes VALUES(1,'Pesan baterai',0,'2026-10-24T11:00:00')")
con.execute("INSERT INTO digital_transactions VALUES(1,'Telkomsel','0812345',30000,5000,'2026-10-24T09:00:00')")

m=re.search(r"CREATE TABLE IF NOT EXISTS digital_events\((.*?)\)'''",block,re.S)
assert m
for _ in range(2):
    for table, fields in [('store_notes',note),('digital_transactions',digital)]:
        existing={x['name'] for x in con.execute('PRAGMA table_info('+table+')')}
        for name,dcl in fields.items():
            if name not in existing:
                con.execute('ALTER TABLE '+table+' ADD COLUMN '+name+' '+dcl)
    con.execute('CREATE TABLE IF NOT EXISTS digital_events('+m.group(1)+')')

n=con.execute('SELECT * FROM store_notes WHERE id=1').fetchone()
assert n['text']=='Pesan baterai' and n['category']=='Umum' and n['priority']=='Normal'
assert n['pinned']==0 and n['due_at']==''
d=con.execute('SELECT * FROM digital_transactions WHERE id=1').fetchone()
assert d['nominal']==30000 and d['fee']==5000 and d['status']=='Selesai'

with con:
    con.execute("UPDATE store_notes SET category='Service',priority='Tinggi',due_at='2026-10-26' WHERE id=1")
    con.execute("UPDATE digital_transactions SET status='Gagal',note='Provider menolak' WHERE id=1")
    con.execute("INSERT INTO digital_events(transaction_id,old_status,new_status,old_note,new_note,created_at) VALUES(1,'Selesai','Gagal','','Provider menolak','2026-10-25')")
assert con.execute('SELECT category FROM store_notes WHERE id=1').fetchone()[0]=='Service'
assert con.execute('SELECT COUNT(*) FROM digital_events').fetchone()[0]==1
assert con.execute("SELECT COALESCE(SUM(fee),0) FROM digital_transactions WHERE status='Selesai'").fetchone()[0]==0
assert con.execute('SELECT nominal FROM digital_transactions WHERE id=1').fetchone()[0]==30000
print('OK: additive SQLite v15, legacy data, note fields, digital status audit and restored version whitelist')
