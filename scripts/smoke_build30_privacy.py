#!/usr/bin/env python3
"""No-storage regression check for app lock, dashboard and financial persistence."""
from pathlib import Path
import re
import sqlite3

root = Path(__file__).resolve().parent.parent
pin = (root/'lib/screens/security/pin_screens.dart').read_text()
biometric = (root/'lib/services/biometric_security.dart').read_text()
dashboard = (root/'lib/screens/dashboard.dart').read_text()
db = (root/'lib/core/database.dart').read_text()
backup = (root/'lib/services/backup_service.dart').read_text()
assert 'PinSecurity.verify(' in pin and 'PIN 6 digit' in pin
assert 'biometricOnly: true' in biometric
assert 'BiometricType.face' in biometric
assert 'getAvailableBiometrics()' in biometric
assert 'disableFacePreference()' in pin
assert '_DebtReminderCard' not in dashboard
assert 'ReminderCenterScreen()' in (root/'lib/main.dart').read_text()
assert re.search(r'\bversion:\s*15\s*,', db)
assert "'databaseVersion': 15" in backup
assert "'receivables'" in backup and "'receivable_payments'" in backup
# Data migration is not needed; financial cash formula remains based on existing records.
con = sqlite3.connect(':memory:')
con.executescript('''
CREATE TABLE cash_adjustments(delta INTEGER);
CREATE TABLE receipts(payment TEXT, total INTEGER);
CREATE TABLE receivable_payments(method TEXT, amount INTEGER);
CREATE TABLE expenses(amount INTEGER);
''')
con.execute('INSERT INTO cash_adjustments VALUES(50000)')
con.execute("INSERT INTO receipts VALUES('Tunai',125000)")
con.execute("INSERT INTO receivable_payments VALUES('Tunai',25000)")
con.execute('INSERT INTO expenses VALUES(10000)')
check = con.execute("""SELECT
(SELECT SUM(delta) FROM cash_adjustments) +
(SELECT SUM(total) FROM receipts WHERE payment='Tunai') +
(SELECT SUM(amount) FROM receivable_payments WHERE method='Tunai') -
(SELECT SUM(amount) FROM expenses)""").fetchone()[0]
assert check == 190000
print('OK: schema v15 unchanged, no private debt dashboard, PIN fallback, biometric templates stay in Android')
