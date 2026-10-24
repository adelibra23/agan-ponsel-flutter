import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'expenses_service.dart';

/// Monthly spending budgets are local preferences, included in store backups.
/// A single preference key avoids adding more SQLite migrations.
class ExpenseBudgetSettings {
  static const key = 'expense_budget_settings';
  static const maxRupiah = 1000000000000;
  final int overall;
  final Map<int, int> byCategory;

  const ExpenseBudgetSettings({this.overall = 0, this.byCategory = const {}});

  static int _validAmount(Object? value) {
    if (value is! num || value != value.roundToDouble()) return 0;
    final amount = value.toInt();
    if (amount < 0 || amount > maxRupiah) return 0;
    return amount;
  }

  static ExpenseBudgetSettings fromJson(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return const ExpenseBudgetSettings();
      final categories = <int, int>{};
      final rawCategories = data['categories'];
      if (rawCategories is Map) {
        for (final entry in rawCategories.entries) {
          final id = int.tryParse(entry.key.toString());
          if (id != null && id > 0) {
            final limit = _validAmount(entry.value);
            if (limit > 0) categories[id] = limit;
          }
        }
      }
      return ExpenseBudgetSettings(
        overall: _validAmount(data['overall']), byCategory: categories);
    } catch (_) {
      return const ExpenseBudgetSettings();
    }
  }

  String toJson() => jsonEncode({
    'overall': overall,
    'categories': {for (final entry in byCategory.entries) '${entry.key}': entry.value},
  });

  static Future<ExpenseBudgetSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromJson(prefs.getString(key) ?? '{}');
  }

  Future<void> save() async {
    if (overall < 0 || overall > maxRupiah ||
        byCategory.values.any((v) => v < 0 || v > maxRupiah)) {
      throw const FormatException('Batas anggaran tidak valid');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, toJson())) {
      throw StateError('Gagal menyimpan anggaran di Android');
    }
  }
}

class ExpenseMonthlyAmount {
  final DateTime month;
  final int total;
  const ExpenseMonthlyAmount(this.month, this.total);
}

class ExpenseFrequentItem {
  final ExpenseEntry source;
  final int times;
  const ExpenseFrequentItem(this.source, this.times);
}

/// Pure calculation: user transactions are never modified by analytics.
class ExpenseInsights {
  final int currentMonthTotal;
  final int previousMonthTotal;
  final int transactionCount;
  final Map<int?, int> categoryTotals;
  final List<ExpenseMonthlyAmount> months;
  final List<ExpenseFrequentItem> frequent;

  const ExpenseInsights({required this.currentMonthTotal,
    required this.previousMonthTotal, required this.transactionCount,
    required this.categoryTotals, required this.months, required this.frequent});

  static ExpenseInsights calculate(List<ExpenseEntry> items, DateTime today) {
    final start = DateTime(today.year, today.month);
    final next = DateTime(today.year, today.month + 1);
    final previous = DateTime(today.year, today.month - 1);
    final current = <ExpenseEntry>[];
    var oldTotal = 0;
    final category = <int?, int>{};
    final monthly = <DateTime, int>{};
    for (var n = 5; n >= 0; n--) {
      monthly[DateTime(today.year, today.month - n)] = 0;
    }
    for (final e in items) {
      if (e.amount < 0) continue;
      final m = DateTime(e.date.year, e.date.month);
      if (monthly.containsKey(m)) monthly[m] = monthly[m]! + e.amount;
      if (!e.date.isBefore(start) && e.date.isBefore(next)) {
        current.add(e);
        category[e.categoryId] = (category[e.categoryId] ?? 0) + e.amount;
      } else if (!e.date.isBefore(previous) && e.date.isBefore(start)) {
        oldTotal += e.amount;
      }
    }
    final currentTotal = current.fold<int>(0, (sum, e) => sum + e.amount);
    final counts = <String, List<ExpenseEntry>>{};
    for (final item in items) {
      final key = '${item.description.trim().toLowerCase()}|${item.categoryId}|${item.unitPrice}|${item.quantity}';
      counts.putIfAbsent(key, () => <ExpenseEntry>[]).add(item);
    }
    final frequent = counts.values.where((group) => group.length >= 2)
      .map((group) {
        group.sort((a, b) => b.date.compareTo(a.date));
        return ExpenseFrequentItem(group.first, group.length);
      }).toList()
      ..sort((a, b) {
        final cmp = b.times.compareTo(a.times);
        return cmp != 0 ? cmp : b.source.date.compareTo(a.source.date);
      });
    return ExpenseInsights(currentMonthTotal: currentTotal,
      previousMonthTotal: oldTotal, transactionCount: current.length,
      categoryTotals: category,
      months: monthly.entries.map((e) => ExpenseMonthlyAmount(e.key, e.value)).toList(),
      frequent: frequent.take(5).toList());
  }

  /// Returns 0 when no budget; otherwise current spending/budget.
  static double usage(int spent, int limit) =>
      limit <= 0 ? 0 : spent / limit;

  static String budgetStatus(int spent, int limit) {
    if (limit <= 0) return 'Belum diatur';
    if (spent >= limit) return 'Mencapai / melewati batas';
    if (spent * 10 >= limit * 8) return 'Mendekati batas (80%)';
    return 'Dalam anggaran';
  }
}
