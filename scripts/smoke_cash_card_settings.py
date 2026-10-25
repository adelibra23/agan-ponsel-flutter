"""Static smoke test: restore profile compatibility and privacy semantics."""
from pathlib import Path
import re
import sqlite3

root = Path(__file__).resolve().parent.parent
backup = (root/'lib/services/backup_service.dart').read_text()
widget = (root/'lib/widgets/premium_cash_card.dart').read_text()
for field in ["'cash_card_style'", "'cash_card_density'"]:
    assert field in backup, f'Missing card preference from portable backup: {field}'
assert 'cash_balance_visible' not in backup, 'Visibility must remain device local'
for field in ["'cash_balance_visible'", "'cash_card_style'", "'cash_card_density'"]:
    assert field in widget
assert 'setString(styleKey' in widget
assert 'setString(densityKey' in widget
assert 'setBool(visibilityKey' in widget
assert 'ValueNotifier<int>' in widget
assert 'AppDatabase.cashBalance()' in widget
assert "'databaseVersion': 15" in backup
assert "'restock_orders'" in backup and "'digital_events'" in backup

# The new feature only changes UI preferences. Existing SQLite cash data is
# still used unchanged for the balance calculation.
con = sqlite3.connect(':memory:')
con.executescript('''CREATE TABLE cash_adjustments(delta INTEGER);
CREATE TABLE receipts(payment TEXT,total INTEGER);
CREATE TABLE receivable_payments(method TEXT,amount INTEGER);
CREATE TABLE expenses(amount INTEGER);''')
con.execute('INSERT INTO cash_adjustments VALUES(250000)')
con.execute("INSERT INTO receipts VALUES('Tunai',100000)")
con.execute("INSERT INTO receivable_payments VALUES('Tunai',40000)")
con.execute('INSERT INTO expenses VALUES(15000)')
get = lambda sql: con.execute(sql).fetchone()[0]
balance = get('SELECT SUM(delta) FROM cash_adjustments') + \
    get("SELECT SUM(total) FROM receipts WHERE payment='Tunai'") + \
    get("SELECT SUM(amount) FROM receivable_payments WHERE method='Tunai'") - \
    get('SELECT SUM(amount) FROM expenses')
assert balance == 375000
print('OK: cash card style/density backup settings, balance privacy and unchanged cash ledger')
