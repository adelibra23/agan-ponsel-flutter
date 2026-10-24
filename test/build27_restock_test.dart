import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/core/database.dart';
import 'package:agan_ponsel/services/restock_service.dart';

void main() {
  test('Restock suggestion respects safety stock', () {
    expect(RestockService.suggestedQty(2, 5), 8);
    expect(RestockService.suggestedQty(6, 5), 0);
    expect(RestockService.suggestedQty(0, 0), 1);
  });

  test('Restock estimated purchase cost uses quantities and product costs', () {
    const first = Product(
      id: 1, name: 'Charger', category: 'Aksesoris', sku: 'C1',
      stock: 2, minStock: 5, cost: 25000, price: 45000,
    );
    const second = Product(
      id: 2, name: 'Kabel', category: 'Aksesoris', sku: 'K1',
      stock: 3, minStock: 4, cost: 10000, price: 20000,
    );
    final planned = <RestockDraftLine>[
      const RestockDraftLine(first, 3),
      const RestockDraftLine(second, 2),
    ];
    expect(RestockService.estimateCost(planned), 95000);
    expect(planned.first.estimatedCost, 75000);
  });
}
