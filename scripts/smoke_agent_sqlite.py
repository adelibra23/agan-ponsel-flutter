"""Basic SQLite schema and upgrade smoke test without Flutter dependencies."""
import re
import sqlite3
from pathlib import Path

text = Path('lib/core/database.dart').read_text()
match = re.search(r"CREATE TABLE IF NOT EXISTS agent_activity\((.*?)\)'''", text, re.S)
if not match:
    raise SystemExit('Missing agent_activity migration SQL')
sql = 'CREATE TABLE IF NOT EXISTS agent_activity(' + match.group(1) + ')'
con = sqlite3.connect(':memory:')
con.execute('CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT)')
con.execute("INSERT INTO products VALUES(1, 'Kabel Charger')")
con.execute(sql)
con.execute(sql)  # idempotent on repeated migration
con.execute("INSERT INTO agent_activity(action, created_at) VALUES(?, ?)",
            ('new_customer', '2026-10-15T12:00:00'))
assert con.execute('SELECT name FROM products').fetchone()[0] == 'Kabel Charger'
assert con.execute('SELECT action FROM agent_activity').fetchone()[0] == 'new_customer'
print('OK: agent audit SQL supports non-destructive upgrade')
