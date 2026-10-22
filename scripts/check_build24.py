from pathlib import Path

required = {
  'lib/services/expenses_service.dart':['class ExpensesService','static Future<void> edit','expense_audit'],
  'lib/screens/expenses_v2.dart':['class ExpensesManagementScreen','class ExpenseEditorPage','class ExpenseCategoriesPage','exportCsv'],
  'lib/core/database.dart':['version: 13','_createExpensesV12','expense_categories','expense_audit'],
  'lib/services/backup_service.dart':["'expense_categories'", "'expense_audit'", "'app_font_family'", "'databaseVersion': 13"],
  'lib/screens/others.dart':['class ExpensesScreen extends StatelessWidget','expenses_v2.dart','Google Drive Otomatis','Alarm Jatuh Tempo'],
  'lib/core/theme.dart':['Rose Quartz','Graphite','aganFontFamily','appFontChoices'],
  'lib/main.dart':['aganFontFamily.addListener','app_font_family','BackgroundJobs.init()'],
  'lib/widgets/identity.dart':['class BrandHeader','PopupMenuButton<String>'],
  'lib/screens/app_templates.dart':['changeFont','appFontChoices'],
  'pubspec.yaml':['version: 1.5.0+25','shared_preferences_android: 2.4.28','splash_blank.png'],
  '.github/workflows/build-apk.yml':['Check AGAN PONSEL Build24','AGAN-PONSEL-v1.5.0-Build25-APK','Test WhatsApp Agent Webhook'],
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
