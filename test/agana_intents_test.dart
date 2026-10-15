import 'package:flutter_test/flutter_test.dart';
import 'package:agan_ponsel/agent/agent_intents.dart';

void main() {
  test('reads debt, stock, service and reports', () {
    expect(AgentParser.parse('cek tagihan Budi').kind, 'debt');
    expect(AgentParser.parse('cek tagihan Budi').argument, 'Budi');
    expect(AgentParser.parse('stok menipis').kind, 'low_stock');
    expect(AgentParser.parse('cek stok charger').kind, 'stock');
    expect(AgentParser.parse('cek service Andi').kind, 'services');
    expect(AgentParser.parse('laporan hari ini').kind, 'summary');
    expect(AgentParser.parse('siapa yang jatuh tempo').kind, 'due_debt');
    expect(AgentParser.parse('bayar piutang Budi').kind, 'pay_debt');
  });

  test('user approval required for all write operations', () {
    for (final text in [
      'tambah pelanggan Budi 081234567890',
      'catat pengeluaran 25000 untuk isolasi',
      'tambah catatan pesan LCD',
      'catat piutang Budi; 150000; 2026-11-01; pulsa',
    ]) {
      expect(AgentParser.parse(text).needsApproval, isTrue, reason: text);
    }
    expect(AgentParser.parse('cek stok kabel').needsApproval, isFalse);
  });

  test('rejects invalid monetary formats and phone numbers', () {
    expect(AgentParser.money('25.000'), 25000);
    expect(AgentParser.money('2,5 juta'), isNull);
    expect(AgentParser.parse('catat pengeluaran 0 untuk bensin').kind, 'invalid_amount');
    expect(AgentParser.parse('catat piutang Budi; x; 2026-11-01; pulsa').needsApproval, isFalse);
  });
}
