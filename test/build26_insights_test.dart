import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/expense_insights_service.dart';
import 'package:agan_ponsel/services/expenses_service.dart';

ExpenseEntry expense(int id, int amount, DateTime date, {int? category = 2}) =>
    ExpenseEntry(
      id: id, description: 'Kertas A4', note: '', method: 'Tunai',
      category: 'ATK', categoryId: category, amount: amount, date: date,
      updatedAt: '', unitPrice: amount, quantity: 1,
    );

void main() {
  test('Current month, previous month and year boundary', () {
    final records = <ExpenseEntry>[
      expense(1, 20000, DateTime(2026, 1, 1)),
      expense(2, 30000, DateTime(2026, 1, 15)),
      expense(3, 12000, DateTime(2025, 12, 31)),
      expense(4, 5000, DateTime(2025, 11, 20)),
    ];
    final result = ExpenseInsights.calculate(records, DateTime(2026, 1, 30));
    expect(result.currentMonthTotal, 50000);
    expect(result.previousMonthTotal, 12000);
    expect(result.transactionCount, 2);
    expect(result.categoryTotals[2], 50000);
    expect(result.months.length, 6);
    expect(result.months.last.total, 50000);
  });

  test('Frequently repeated expenses suggest one-tap reuse', () {
    final result = ExpenseInsights.calculate([
      expense(1, 5000, DateTime(2026, 3, 4)),
      expense(2, 5000, DateTime(2026, 3, 8)),
      expense(3, 2000, DateTime(2026, 3, 9)),
    ], DateTime(2026, 3, 15));
    expect(result.frequent.length, 1);
    expect(result.frequent.single.times, 2);
    expect(result.frequent.single.source.id, 2);
  });

  test('Budget status and robust preferences JSON', () {
    expect(ExpenseInsights.budgetStatus(80000, 100000), contains('80%'));
    expect(ExpenseInsights.budgetStatus(100000, 100000), contains('batas'));
    expect(ExpenseInsights.budgetStatus(10000, 0), 'Belum diatur');
    final saved = ExpenseBudgetSettings(overall: 300000,
      byCategory: {2: 60000, 3: 40000}).toJson();
    final restored = ExpenseBudgetSettings.fromJson(saved);
    expect(restored.overall, 300000);
    expect(restored.byCategory[2], 60000);
    expect(ExpenseBudgetSettings.fromJson('invalid').overall, 0);
    expect(ExpenseBudgetSettings.fromJson('{"overall":-1}').overall, 0);
  });
}
