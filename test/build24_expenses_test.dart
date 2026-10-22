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
    expect(expense.quantity, 1);
    expect(expense.unitPrice, 45000);
    expect(expense.merchant, '');
  });

  test('Expense pricing validates multiplication and limits', () {
    expect(ExpensesService.calculateAmount(unitPrice: 12500, quantity: 3), 37500);
    expect(() => ExpensesService.calculateAmount(unitPrice: 0, quantity: 2),
      throwsFormatException);
    expect(() => ExpensesService.calculateAmount(unitPrice: 1200, quantity: 0),
      throwsFormatException);
    expect(() => ExpensesService.calculateAmount(unitPrice: 1200, quantity: 10000),
      throwsFormatException);
  });

  test('Category icon and color have robust old-data fallbacks', () {
    final old = ExpenseCategory.from({'id': 1, 'name': 'Lainnya', 'archived': 0});
    expect(old.iconKey, 'receipt');
    expect(ExpensesService.iconKeys, contains('shopping'));
    expect(ExpensesService.colors.length, greaterThanOrEqualTo(6));
  });

  test('Themes and fonts can be selected without downloading assets', () {
    expect(appTemplates, contains('Golden'));
    expect(appTemplates.length, greaterThanOrEqualTo(8));
    expect(appFontChoices.containsKey('Roboto'), true);
    expect(appFontChoices.containsKey('serif'), true);
  });
}

// Build 25: pricing and visual category metadata are backward compatible.
