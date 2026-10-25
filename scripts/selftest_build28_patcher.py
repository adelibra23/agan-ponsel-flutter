"""Check v15 column SQL against the patch source using Python stdlib.
Does not require Flutter or repo checkout; run inside patch ZIP folder.
"""
from pathlib import Path
import ast
import re
import sqlite3

text = Path('scripts/apply_build28.py').read_text()
tree = ast.parse(text)
node = next(node for node in tree.body if isinstance(node, ast.Assign)
            and any(isinstance(t, ast.Name) and t.id == 'DB_METHOD' for t in node.targets))
method = ast.literal_eval(node.value)
assert 'static Future<void> _createOperationsV15' in method
n = re.search(r'const noteFields = <String, String>\{(.*?)\n    \};', method, re.S)
d = re.search(r'const digitalFields = <String, String>\{(.*?)\n    \};', method, re.S)
assert n and d
con = sqlite3.connect(':memory:')
con.execute('CREATE TABLE store_notes(id INTEGER PRIMARY KEY, text TEXT, done INTEGER, created_at TEXT)')
con.execute('CREATE TABLE digital_transactions(id INTEGER PRIMARY KEY, operator TEXT, destination TEXT, nominal INTEGER, fee INTEGER, created_at TEXT)')
con.execute("INSERT INTO store_notes VALUES(1,'Tugas lama',0,'2026-10-24')")
con.execute("INSERT INTO digital_transactions VALUES(1,'XL','08123',25000,5000,'2026-10-24')")
for table, chunk in [('store_notes', n.group(1)), ('digital_transactions',d.group(1))]:
    definitions = re.findall(r"'([^']+)':\s*(['\"])(.*?)\2\s*,",chunk)
    assert definitions
    for col,_,ddl in definitions:
        con.execute(f'ALTER TABLE {table} ADD COLUMN {col} {ddl}')
m = re.search(r"CREATE TABLE IF NOT EXISTS digital_events\((.*?)\)'''", method, re.S)
assert m
con.execute('CREATE TABLE digital_events('+m.group(1)+')')
assert con.execute("SELECT category FROM store_notes").fetchone()[0]=='Umum'
assert con.execute("SELECT status FROM digital_transactions").fetchone()[0]=='Selesai'
assert 'digital_events' in [row[0] for row in con.execute("SELECT name FROM sqlite_master WHERE type='table'")]
print('OK: Build28 v15 migration SQL compiles in SQLite and preserves old rows')
