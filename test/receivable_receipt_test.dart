import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/services/receivable_receipt_service.dart';
import 'package:agan_ponsel/services/receivables_service.dart';

void main() {
  final receivable = Receivable(
    id: 42,
    customer: 'Siti Aminah',
    phone: '081234567890',
    description: 'Charger dan kabel',
    notes: 'Bayar sebelum tanggal jatuh tempo',
    dueDate: '2026-11-01',
    createdAt: '2026-10-19T12:00:00',
    amount: 80000,
    paid: 20000,
  );
  final sample = ReceivableReceiptData(
    receivable: receivable,
    lines: const [
      ReceivableLine(description: 'Charger', qty: 2, unitPrice: 25000),
      ReceivableLine(description: 'Kabel Data', qty: 3, unitPrice: 10000),
    ],
    payments: const [],
    shopName: 'AGAN PONSEL',
    address: 'Sekeladi, Tanah Putih',
    shopPhone: '08100000000',
    footer: 'Terima kasih',
    admin: 'Admin',
  );

  test('Status piutang dihitung dari pembayaran aktual', () {
    expect(debtReceiptStatus(80000, 0), 'BELUM LUNAS');
    expect(debtReceiptStatus(80000, 20000), 'CICILAN');
    expect(debtReceiptStatus(80000, 80000), 'LUNAS');
  });

  test('Nomor nota stabil untuk id piutang', () {
    expect(debtReceiptNumber(42), 'AGP-000042');
    expect(sample.number, 'AGP-000042');
  });

  test('Semua harga dan sisa piutang muncul di nota thermal 58 mm', () {
    final receipt = receivableThermalText(sample, chars: 32);
    expect(receipt, contains('AGP-000042'));
    expect(receipt, contains('Siti Aminah'));
    expect(receipt, contains('2 x Rp25.000'));
    expect(receipt, contains('3 x Rp10.000'));
    expect(receipt, contains('Rp80.000'));
    expect(receipt, contains('Rp20.000'));
    expect(receipt, contains('Rp60.000'));
    expect(receipt, contains('CICILAN'));
  });

  test('Format thermal 80 mm memakai lebar 48 karakter', () {
    final receipt = receivableThermalText(sample, chars: 48);
    expect(receipt, contains('RINCIAN TAGIHAN'));
    expect(receipt, contains('SISA'));
    expect(receipt, contains('Rp60.000'));
  });
}
