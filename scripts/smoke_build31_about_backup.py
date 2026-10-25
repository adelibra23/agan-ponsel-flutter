"""Static smoke test of added public contact backup keys and privacy rules."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
backup = (root / 'lib/services/backup_service.dart').read_text()
model = (root / 'lib/services/store_about_profile.dart').read_text()
keys = [
    'local_shop_about', 'local_shop_hours', 'local_shop_contact_phone',
    'local_shop_contact_whatsapp', 'local_shop_contact_email',
    'local_shop_instagram', 'local_shop_website',
]
for key in keys:
    assert re.search(r"['\"]" + re.escape(key) + r"['\"]", backup), key
    assert key in model, key
assert 'local_owner_phone' in backup, 'Previous backup identity fields must survive'
for secret in ['local_biometrics_enabled_v1', 'local_face_preferred_v30',
               'local_pin_hash_v1', 'cash_balance_visible']:
    assert secret not in backup, secret
assert "'databaseVersion': 15" in backup, 'Build31 does not modify SQLite'
print('OK: Public shop contact keys included in backup; device security remains private')
