from pathlib import Path
checks = {
 'lib/core/database.dart': [
   'version: 13','if (oldVersion < 13)','_createExpensesV13',
   'unit_price','quantity','merchant','reference_code','icon_key','color_value',
 ],
 'lib/services/expenses_service.dart': [
   'calculateAmount','_validateExtra','updateCategory','unit_price','icon_key',
   'reference_code',"'color_value': colorValue",'expense_audit',
 ],
 'lib/screens/expenses_v2.dart': [
   'Harga satuan (Rp)','Total pengeluaran','expense-category-tabs',
   'showExpenseCategoryEditor','Pilih warna','Pilih ikon','No. nota / referensi',
 ],
 'lib/services/backup_service.dart': [
   "'databaseVersion': 13",'10, 11, 12, 13',"'expense_categories'","'expense_audit'",
 ],
 'pubspec.yaml': ['version: 1.5.0+25','shared_preferences_android: 2.4.28'],
 '.github/workflows/build-apk.yml': ['scripts/smoke_expenses_v13.py','Build25-APK','Test WhatsApp Agent Webhook'],
}
for name, needles in checks.items():
    text = Path(name).read_text()
    for token in needles:
        assert token in text, f'{name}: missing {token}'
assert Path('lib/screens/others.dart').read_text().count('ExpensesManagementScreen')>0
print('OK: Build25 source integration and Build21/23/24 features retained')
