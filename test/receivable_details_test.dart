import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/receivables_service.dart';

void main() {
  test('Normalisasi nomor WhatsApp Indonesia', () {
    expect(whatsappPhone('0812-3456-7890'), '6281234567890');
    expect(whatsappPhone('+62 812 3456 7890'), '6281234567890');
    expect(whatsappPhone('81234567890'), '6281234567890');
    expect(whatsappPhone('0062 812 3456 7890'), '6281234567890');
    expect(whatsappPhone('nomor tidak ada'), isNull);
    expect(whatsappPhone('123'), isNull);
  });

  test('Total berasal dari qty kali harga masing-masing baris', () {
    final items = [
      const ReceivableLine(description: 'Charger', qty: 2, unitPrice: 25000),
      const ReceivableLine(description: 'Kabel', qty: 3, unitPrice: 10000),
    ];
    expect(items.first.total, 50000);
    expect(items.last.total, 30000);
    expect(ReceivablesService.calculateTotal(items), 80000);
  });

  test('Tolak jumlah 0 dan total yang melampaui batas', () {
    expect(() => ReceivablesService.calculateTotal([]), throwsFormatException);
    expect(() => ReceivablesService.calculateTotal([
      const ReceivableLine(description: 'Kabel', qty: 0, unitPrice: 5000),
    ]), throwsFormatException);
    expect(() => ReceivablesService.calculateTotal([
      const ReceivableLine(description: 'Barang A', qty: 2, unitPrice: 600000000),
    ]), throwsFormatException);
  });
}
