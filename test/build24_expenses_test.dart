import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/expenses_service.dart';
import 'package:agan_ponsel/core/theme.dart';

void main() {
  test('Old expense rows remain readable after additive SQLite upgrade', () {
    final expense = ExpenseEntry.from(<String, Object?>{
      'id': 7, 'description': 'Ganti sparepart', 'amount': 45000,
      'created_at': '2026-10-11T13:30:00', 'category_name': 'Lainnya',
    });
    expect(expense.id, 7);
    expect(expense.amount, 45000);
    expect(expense.method, 'Tunai');
    expect(expense.note, '');
    expect(expense.category, 'Lainnya');
    expect(expense.date.hour, 13);
  });

  test('Themes and fonts can be selected without downloading assets', () {
    expect(appTemplates, contains('Golden'));
    expect(appTemplates.length, greaterThanOrEqualTo(8));
    expect(appFontChoices.containsKey('Roboto'), true);
    expect(appFontChoices.containsKey('serif'), true);
  });
}
