import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/receivables_service.dart';
import 'package:agan_ponsel/services/receivable_receipt_service.dart';

void main() {
  test('Tanggal bon ISO sah, termasuk tahun kabisat', () {
    expect(validEntryDate('2026-10-21'), true);
    expect(validEntryDate('2024-02-29'), true);
    expect(validEntryDate('2026-02-29'), false);
    expect(validEntryDate('2026-02-31'), false);
    expect(validEntryDate('21/10/2026'), false);
  });

  test('Penambahan beberapa bon menjumlah subtotal yang tepat', () {
    const items = [
      ReceivableLine(description: 'Charger', qty: 2, unitPrice: 25000,
        entryDate: '2026-10-20'),
      ReceivableLine(description: 'Kabel data', qty: 1, unitPrice: 15000,
        entryDate: '2026-10-21'),
    ];
    expect(ReceivablesService.calculateTotal(items), 65000);
    expect(items[0].entryDate, '2026-10-20');
    expect(items[1].entryDate, '2026-10-21');
  });

  test('Tanggal bon invalid ditolak', () {
    expect(() => ReceivablesService.calculateTotal(const [
      ReceivableLine(description: 'Produk', qty: 1, unitPrice: 20000,
        entryDate: '2026-02-30'),
    ]), throwsFormatException);
  });

  test('Nota thermal memasukkan tanggal setiap bon', () {
    const debt = Receivable(id: 3, customer: 'Budi', phone: '',
      description: 'Bon pelanggan', notes: '', dueDate: '2026-11-05',
      createdAt: '2026-10-20T12:00:00', amount: 25000, paid: 5000);
    const receipt = ReceivableReceiptData(
      receivable: debt,
      lines: [ReceivableLine(description: 'Kabel', qty: 1,
        unitPrice: 25000, entryDate: '2026-10-21')],
      payments: [], shopName: 'AGAN PONSEL', address: '',
      shopPhone: '', footer: '', admin: 'Kasir');
    final text = receivableThermalText(receipt);
    expect(text, contains('Kabel'));
    expect(text, contains('2026'));
    expect(text, contains('Rp20.000'));
  });
}
