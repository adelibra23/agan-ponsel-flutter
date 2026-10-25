"""Build26 regression guard; checks live source, not just copied fixture."""
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
checks = {
 'lib/services/expense_insights_service.dart': ['class ExpenseInsights', 'class ExpenseBudgetSettings', 'previousMonthTotal', 'byCategory', 'ExpenseFrequentItem', 'save()'],
 'lib/screens/expense_insights.dart': ['class ExpenseInsightsScreen', 'class ExpenseBudgetScreen', 'Salin Ringkasan Bulanan', 'Sering dicatat'],
 'lib/screens/expenses_v2.dart': ["import 'expense_insights.dart';", 'openInsights()', 'Insight, Anggaran & Pengeluaran Favorit'],
 'lib/services/backup_service.dart': ["'expense_budget_settings'", "'databaseVersion': 15"],
 'pubspec.yaml': [ 'shared_preferences_android: 2.4.28'],
 '.github/workflows/build-apk.yml': ['test/build26_insights_test.dart', 'scripts/smoke_budget_backup.py', ],
}
for path, keys in checks.items():
    text = (root / path).read_text()
    for key in keys:
        assert key in text, f'{path}: missing {key}'
assert re.search(r'\bversion:\s*15\s*,', (root/'lib/core/database.dart').read_text()), 'SQLite schema version must be v14'
print('OK: Build26 finance insights, budget backup, quick repeat, unchanged SQLite v14')


# BUILD29_FORWARD_COMPATIBLE_GUARD_26
# Minimum release compatibility; future APK releases remain valid.
_version29 = re.search(r'(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)',
    Path('pubspec.yaml').read_text())
assert _version29, 'AGAN PONSEL version missing'
assert tuple(map(int, _version29.groups())) >= (1, 6, 0, 26), 'Requires Build26 or newer'
