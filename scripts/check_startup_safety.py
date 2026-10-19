"""Small CI guard for safe startup / non-destructive migrations.
Does not replace Android on-device testing or Flutter analysis.
"""
from pathlib import Path

main = Path('lib/main.dart').read_text()
security = Path('lib/screens/security/pin_screens.dart').read_text()
db = Path('lib/core/database.dart').read_text()
workflow = Path('.github/workflows/build-apk.yml').read_text()
assert 'class AganStartupGate' in main
assert 'snapshot.hasError' in main and 'Coba Lagi' in main
assert 'home: AganStartupGate(' in main
assert 'class _SplashGateState' in main
assert 'checkFailed' in security and 'PinSecurity.enabled.timeout(' in security
assert 'Fail closed' in security
assert 'static Future<Database> _openRecoverable() async' in db
assert 'onOpen: (db) async {' in db
assert 'await _createReceiptEvents(db);' in db
assert 'DROP TABLE' not in db.upper()
assert 'DELETE FROM' not in db.upper()
assert 'Finalize Android startup theme' in workflow
print('PASS: startup guard, PIN fail-closed, additive SQLite repair checks')
