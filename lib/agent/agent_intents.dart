/// AGANA v0.8: local Indonesian command recognition; no external LLM or network.
/// Parser never writes data. Mutations require explicit approval in the UI.
class AgentIntent {
  final String kind;
  final String argument;
  final String description;
  final int amount;
  final DateTime? dueDate;
  final String phone;
  const AgentIntent(this.kind, {this.argument = '', this.description = '',
    this.amount = 0, this.dueDate, this.phone = ''});

  bool get needsApproval => const {
    'new_customer', 'new_expense', 'new_note', 'new_debt'
  }.contains(kind);
}

class AgentParser {
  AgentParser._();

  static int? money(String input) {
    final trimmed = input.trim().toLowerCase().replaceAll(RegExp(r'^rp\s*'), '');
    if (!RegExp(r'^\d{1,12}(?:\.\d{3})*$').hasMatch(trimmed)) return null;
    final value = int.tryParse(trimmed.replaceAll('.', ''));
    if (value == null || value <= 0 || value > 1000000000) return null;
    return value;
  }

  static AgentIntent parse(String raw) {
    final input = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final lower = input.toLowerCase();
    if (input.isEmpty) return const AgentIntent('help');

    // Structured separators make monetary commands unambiguous, yet the other
    // commands below also accept ordinary Indonesian sentences.
    final debt = RegExp(r'^(?:buat|catat|input|tambah|masukkan)\s+(?:piutang|tagihan)\s+(.+?)\s*;\s*(rp\s*)?([\d.]+)\s*;\s*(\d{4}-\d{2}-\d{2})\s*;\s*(.+)$', caseSensitive: false).firstMatch(input);
    if (debt != null) {
      final amount = money(debt.group(3)!);
      final due = DateTime.tryParse(debt.group(4)!);
      if (amount == null || due == null || due.toIso8601String().substring(0, 10) != debt.group(4)) {
        return const AgentIntent('invalid_debt');
      }
      return AgentIntent('new_debt', argument: debt.group(1)!.trim(), amount: amount,
        dueDate: due, description: debt.group(5)!.trim());
    }

    final customer = RegExp(r'^(?:tambah|catat|input|masukkan|buat)\s+pelanggan\s+(.+?)\s+(\+?[\d -]{8,20})$', caseSensitive: false).firstMatch(input);
    if (customer != null) {
      final phone = customer.group(2)!.replaceAll(RegExp(r'[^\d+]'), '');
      if (!RegExp(r'^\+?\d{8,15}$').hasMatch(phone)) {
        return const AgentIntent('invalid_customer');
      }
      return AgentIntent('new_customer', argument: customer.group(1)!.trim(), phone: phone);
    }
    final expense = RegExp(r'^(?:catat|tambah|input|masukkan|buat)\s+pengeluaran\s+(?:rp\s*)?([\d.]+)\s+(?:untuk\s+)?(.+)$', caseSensitive: false).firstMatch(input);
    if (expense != null) {
      final amount = money(expense.group(1)!);
      if (amount == null) return const AgentIntent('invalid_amount');
      return AgentIntent('new_expense', amount: amount, description: expense.group(2)!.trim());
    }
    final note = RegExp(r'^(?:catat|tambah|input|masukkan|buat)\s+(?:catatan|tugas)\s+(.+)$', caseSensitive: false).firstMatch(input);
    if (note != null) return AgentIntent('new_note', description: note.group(1)!.trim());

    final creates = RegExp(r'^(?:catat|tambah|input|masukkan|buat)\s+');
    if (creates.hasMatch(lower)) {
      if (lower.contains('piutang') || lower.contains('tagihan')) return const AgentIntent('open_debt');
      if (lower.contains('service') || lower.contains('servis')) return const AgentIntent('open_service');
      if (lower.contains('produk') || lower.contains('stok')) return const AgentIntent('open_inventory');
      if (lower.contains('pelanggan')) return const AgentIntent('open_customers');
      if (lower.contains('pengeluaran')) return const AgentIntent('open_expenses');
      if (lower.contains('catatan') || lower.contains('tugas')) return const AgentIntent('open_notes');
    }

    if (RegExp(r'^(?:bayar|cicil|lunasi|pelunasan|ubah jatuh tempo|ubah tanggal)\b').hasMatch(lower)
        && (lower.contains('piutang') || lower.contains('tagihan'))) {
      return const AgentIntent('pay_debt');
    }
    if (lower.contains('stok') || lower.contains('produk') || lower.contains('barang')) {
      if (RegExp(r'menipis|habis|minimum|kosong|sedikit').hasMatch(lower)) {
        return const AgentIntent('low_stock');
      }
      final query = input.replaceFirst(RegExp(r'^(?:cek|cari|lihat|berapa|tampilkan)\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^(?:stok|produk|barang)\s*', caseSensitive: false), '').trim();
      return AgentIntent('stock', argument: query);
    }
    if (lower.contains('service') || lower.contains('servis') || lower.contains('perbaikan hp')) {
      final query = input.replaceFirst(RegExp(r'^(?:cek|cari|lihat|status|tampilkan)\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^(?:service|servis|perbaikan hp)\s*', caseSensitive: false), '').trim();
      return AgentIntent('services', argument: query);
    }
    if (RegExp(r'laporan|omzet|ringkasan|penjualan hari ini|keuntungan|laba').hasMatch(lower)) {
      return AgentIntent('summary', argument: RegExp(r'hari ini|sekarang').hasMatch(lower) ? 'today' : 'all');
    }
    if (lower.contains('saldo') || lower.contains('kas toko')) return const AgentIntent('cash');
    if (RegExp(r'jatuh tempo|terlambat|belum bayar|menunggak|pengingat').hasMatch(lower)) {
      return const AgentIntent('due_debt');
    }
    if (lower.contains('tagihan') || lower.contains('piutang')) {
      final query = input.replaceFirst(RegExp(r'^(?:cek|cari|lihat|berapa|tampilkan|status)\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^(?:tagihan|piutang)\s*', caseSensitive: false), '').trim();
      return AgentIntent('debt', argument: query);
    }
    if (RegExp(r'kontak|pelanggan').hasMatch(lower)) return const AgentIntent('open_customers');
    if (RegExp(r'riwayat penjualan|kasir').hasMatch(lower)) return const AgentIntent('open_sales');
    if (RegExp(r'tugas|catatan').hasMatch(lower)) return const AgentIntent('open_notes');
    if (RegExp(r'bantu|fitur|halo|hai|apa yang bisa|contoh|perintah|input data|\bai\b|agana').hasMatch(lower)) {
      return const AgentIntent('help');
    }
    return const AgentIntent('unknown');
  }
}
