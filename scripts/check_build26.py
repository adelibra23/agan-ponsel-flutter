"""Build26 regression guard; checks live source, not just copied fixture."""
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
checks = {
 'lib/services/expense_insights_service.dart': ['class ExpenseInsights', 'class ExpenseBudgetSettings', 'previousMonthTotal', 'byCategory', 'ExpenseFrequentItem', 'save()'],
 'lib/screens/expense_insights.dart': ['class ExpenseInsightsScreen', 'class ExpenseBudgetScreen', 'Salin Ringkasan Bulanan', 'Sering dicatat'],
 'lib/screens/expenses_v2.dart': ["import 'expense_insights.dart';", 'openInsights()', 'Insight, Anggaran & Pengeluaran Favorit'],
 'lib/services/backup_service.dart': ["'expense_budget_settings'", "'databaseVersion': 14"],
 'pubspec.yaml': ['version: 1.7.0+27', 'shared_preferences_android: 2.4.28'],
 '.github/workflows/build-apk.yml': ['test/build26_insights_test.dart', 'scripts/smoke_budget_backup.py', 'AGAN-PONSEL-v1.7.0-Build27-APK'],
}
for path, keys in checks.items():
    text = (root / path).read_text()
    for key in keys:
        assert key in text, f'{path}: missing {key}'
assert re.search(r'\bversion:\s*14\s*,', (root/'lib/core/database.dart').read_text()), 'SQLite schema version must be v14'
print('OK: Build26 finance insights, budget backup, quick repeat, unchanged SQLite v14')
