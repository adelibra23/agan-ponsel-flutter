from pathlib import Path

required = {
  'lib/services/expenses_service.dart':['class ExpensesService','static Future<void> edit','expense_audit'],
  'lib/screens/expenses_v2.dart':['class ExpensesManagementScreen','class ExpenseEditorPage','class ExpenseCategoriesPage','exportCsv'],
  'lib/core/database.dart':['version: 15','_createExpensesV12','expense_categories','expense_audit'],
  'lib/services/backup_service.dart':["'expense_categories'", "'expense_audit'", "'app_font_family'", "'databaseVersion': 15"],
  'lib/screens/others.dart':['class ExpensesScreen extends StatelessWidget','expenses_v2.dart','Google Drive Otomatis','Alarm Jatuh Tempo'],
  'lib/core/theme.dart':['Rose Quartz','Graphite','aganFontFamily','appFontChoices'],
  'lib/main.dart':['aganFontFamily.addListener','app_font_family','BackgroundJobs.init()'],
  'lib/widgets/identity.dart':['class BrandHeader','PopupMenuButton<String>'],
  'lib/screens/app_templates.dart':['changeFont','appFontChoices'],
  'pubspec.yaml':['shared_preferences_android: 2.4.28','splash_blank.png'],
  '.github/workflows/build-apk.yml':['Check AGAN PONSEL Build24','Test WhatsApp Agent Webhook'],
}
for file, tokens in required.items():
    p=Path(file)
    assert p.exists(), f'{file} missing'
    text=p.read_text()
    for token in tokens:
        assert token in text, f'{token} missing in {file}'
assert Path('assets/branding/splash_blank.png').exists()
assert 'version: 11' not in Path('lib/core/database.dart').read_text()
print('OK: Build24 expense, typography, header, splash; Build21/23 integrations preserved')


# Build26 forward-compatible version guard
import re as _re_build26
_version = _re_build26.search(r'(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)',
    Path('pubspec.yaml').read_text())
assert _version, 'App version missing'
_values = tuple(int(x) for x in _version.groups())
assert _values >= (1, 4, 0, 24), 'Requires Build24 or newer'
