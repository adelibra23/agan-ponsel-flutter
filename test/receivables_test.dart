import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/receivables_service.dart';
import 'package:agan_ponsel/screens/receivables.dart';
import 'package:agan_ponsel/core/theme.dart';

void main() {
  test('Piutang calculates outstanding and remains', () {
    final due = DateTime.now().subtract(const Duration(days: 2));
    final item = Receivable(id: 1, customer: 'Pelanggan', phone: '0812345678',
      description: 'Charger', notes: '',
      dueDate: due.toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toIso8601String(), amount: 50000, paid: 15000);
    expect(item.remaining, 35000);
    expect(item.isPaid, isFalse);
    expect(item.overdue, isTrue);
    expect(reminderText(item, 'Ramah'), contains('35.000'));
    expect(reminderText(item, 'Formal'), contains('AGAN PONSEL'));
  });

  test('Template palettes defined for eight Build24 styles', () {
    const requiredTemplates = [
      'Biru Orbit', 'Midnight', 'Emerald', 'Sunset',
      'Ocean', 'Rose Quartz', 'Graphite', 'Golden',
    ];
    expect(appTemplates, containsAll(requiredTemplates));
    expect(appTemplates.length, greaterThanOrEqualTo(8));
    expect(appTemplates.toSet().length, appTemplates.length);
    for (final template in appTemplates) {
      expect(templateGradient(template).length, 3,
        reason: 'Tema $template harus memiliki 3 warna gradien.');
    }
  });
}
