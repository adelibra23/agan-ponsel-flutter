#!/usr/bin/env python3
"""Build31 source guard; checks additions and old safety invariants.

Not a replacement for Flutter analyze, widget tests or testing on an Android phone.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
checks = {
    'lib/main.dart': [
        'BUILD31_TAB_CONTENT_MOTION', 'SingleTickerProviderStateMixin',
        'AnimationController(', '_tabMotion.forward(from: 0)',
        'AnimatedBuilder(', 'Curves.easeOutCubic', 'Transform.translate(',
        'Transform.scale(', 'IndexedStack(index: selected',
        'AnimatedBottomBar(', 'PinGate(',
    ],
    'lib/screens/settings/settings_pages.dart': [
        "import 'about_store.dart';", 'BUILD31_ABOUT_WRAPPER',
        'class AboutAganScreen', 'AboutStoreScreen()',
        'class AccountSettingsScreen', 'class StoreBrandSettingsScreen',
    ],
    'lib/screens/settings/about_store.dart': [
        'class AboutStoreScreen', 'class _EditAboutStoreScreen',
        'PackageInfo.fromPlatform()', 'SharePlus.instance.share(',
        'StoreAboutProfile.load()', 'StoreAboutProfile(',
        'WhatsApp', 'Instagram', 'Sunting Profil Toko',
        'Simpan Tentang Toko', 'launchUrl(', 'about-agan-scroll',
    ],
    'lib/services/store_about_profile.dart': [
        'class StoreAboutProfile', 'class ShopContactLinks',
        'whatsappNumber(', 'websiteUri(', 'instagramUri(',
        'local_shop_contact_phone', 'local_shop_about', 'local_shop_hours',
    ],
    'lib/services/backup_service.dart': [
        "'local_shop_about'", "'local_shop_hours'", "'local_shop_contact_phone'",
        "'local_shop_contact_whatsapp'", "'local_shop_contact_email'",
        "'local_shop_instagram'", "'local_shop_website'",
        "'databaseVersion': 15", "'cash_card_style'",
    ],
    'pubspec.yaml': [
        'version: 2.1.0+31', 'package_info_plus: ^10.2.2',
        'shared_preferences_android: 2.4.28',
    ],
    '.github/workflows/build-apk.yml': [
        'AGAN-PONSEL-v2.1.0-Build31-APK', 'scripts/check_build31.py',
        'test/build31_about_test.dart', 'Test WhatsApp Agent Webhook',
    ],
    'scripts/check_build29.py': ['version: 2.1.0+31'],
    'scripts/check_build30.py': ['version: 2.1.0+31'],
}
for path, fragments in checks.items():
    file = root / path
    assert file.is_file(), f'Missing: {path}'
    normalized = re.sub(r'\s+', '', file.read_text())
    for fragment in fragments:
        assert re.sub(r'\s+', '', fragment) in normalized, (
            f'{path} missing {fragment!r}')

main = (root / 'lib/main.dart').read_text()
assert 'child: IndexedStack(index: selected' in main, 'Tab states must remain mounted'
assert '_tabMotion.dispose()' in main, 'Animation controller must be disposed'
backup = (root / 'lib/services/backup_service.dart').read_text()
for private in ['local_face_preferred_v30', 'local_pin_hash_v1', 'cash_balance_visible']:
    assert private not in backup, f'Device-only/private state must not enter backup: {private}'
db = (root / 'lib/core/database.dart').read_text()
assert re.search(r'\bversion:\s*15\s*,', db), 'SQLite schema must remain v15'
assert 'Flutter • v1.1.0 Build 21' not in (
    root / 'lib/screens/settings/settings_pages.dart').read_text()
assert '_DebtReminderCard' not in (root / 'lib/screens/dashboard.dart').read_text()
print('OK: Build31 animated tab content, About editor, safe contacts and backup')
