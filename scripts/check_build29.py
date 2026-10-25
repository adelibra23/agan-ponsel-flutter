#!/usr/bin/env python3
"""Build29 source guard; Flutter analyzer and widget tests still run in Actions."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
checks = {
 'lib/widgets/premium_cash_card.dart': [
   'class PremiumCashCard', 'class CashCardSettings',
   'CashCardThemePreview', 'CashCardAppearance',
   'static Future<void> setStyle', 'static Future<void> setCompact',
   'static Future<void> setVisible', 'revision.addListener',
   'cash_balance_visible', 'BUKU KAS  •  BUKAN SALDO BANK',
   "'obsidian'", "'rose'", "'graphite'",
 ],
 'lib/screens/settings/cash_card_settings.dart': [
   'class CashCardSettingsScreen', 'CashCardThemePreview',
   'Kartu Ringkas', 'Tampilkan Saldo', 'CashCardSettings.setStyle',
 ],
 'lib/screens/cash_screen.dart': [
   'class BalanceCard extends StatelessWidget',
   'PremiumCashCard(', 'CashCardSettingsScreen',
   'Pilihan Kartu Premium',
 ],
 'lib/screens/others.dart': [
   "import 'settings/cash_card_settings.dart';",
   "title: 'Pilihan Kartu Premium'", "title: 'Desain Kartu Saldo'",
 ],
 'lib/services/backup_service.dart': [
   "'cash_card_style'", "'cash_card_density'", "'databaseVersion': 15",
 ],
 'pubspec.yaml': ['version: 2.0.0+30', 'shared_preferences_android: 2.4.28'],
 '.github/workflows/build-apk.yml': [
   'AGAN-PONSEL-v2.0.0-Build30-APK',
   'scripts/smoke_cash_card_settings.py',
   'test/build29_cash_card_test.dart',
   'Test WhatsApp Agent Webhook',
 ],
}
for name, markers in checks.items():
    f = root/name
    assert f.is_file(), f'File proyek hilang: {name}'
    content = f.read_text()
    normal = re.sub(r'\s+', '', content)
    for marker in markers:
        assert re.sub(r'\s+', '', marker) in normal, f'{name}: missing {marker!r}'

widget = (root/'lib/widgets/premium_cash_card.dart').read_text()
assert len(re.findall(r"CashCardPreset\('([a-z]+)'", widget)) == 8
assert (root/'lib/screens/dashboard.dart').is_file()
assert 'BalanceCard(' in (root/'lib/screens/dashboard.dart').read_text()
backup = (root/'lib/services/backup_service.dart').read_text()
assert 'cash_balance_visible' not in backup, 'Saldo visibility must remain device local'
print('OK: Build29 premium cash cards, shared dashboard, settings and backup')
