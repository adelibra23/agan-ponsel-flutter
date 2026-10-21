import 'package:sqflite/sqflite.dart';
import '../core/database.dart';

/// Piutang tercatat, terpisah dari transaksi kasir dan saldo bank.
/// Pembayaran diproses atomik agar tidak melampaui nominal tagihan.
class Receivable {
  final int id;
  final String customer;
  final String phone;
  final String description;
  final String notes;
  final String dueDate;
  final String createdAt;
  final int amount;
  final int paid;

  const Receivable({
    required this.id, required this.customer, required this.phone,
    required this.description, required this.notes, required this.dueDate,
    required this.createdAt, required this.amount, required this.paid,
  });

  factory Receivable.fromRow(Map<String, Object?> row) => Receivable(
    id: row['id'] as int,
    customer: row['customer_name'] as String,
    phone: row['phone'] as String,
    description: row['description'] as String,
    notes: row['notes'] as String,
    dueDate: row['due_date'] as String,
    createdAt: row['created_at'] as String,
    amount: (row['amount'] as num).toInt(),
    paid: (row['paid'] as num).toInt(),
  );

  int get remaining => amount - paid;
  bool get isPaid => remaining <= 0;
  int get daysLeft {
    final d = DateTime.parse(dueDate);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).difference(start).inDays;
  }
  bool get overdue => !isPaid && daysLeft < 0;
  bool get dueSoon => !isPaid && daysLeft >= 0 && daysLeft <= 3;
  String get dueText {
    if (isPaid) return 'Lunas';
    if (daysLeft < 0) return 'Terlambat ${-daysLeft} hari';
    if (daysLeft == 0) return 'Jatuh tempo hari ini';
    if (daysLeft <= 3) return 'Jatuh tempo $daysLeft hari lagi';
    return 'Jatuh tempo $dueDate';
  }
}

/// Baris item piutang. Harga satuan dan kuantitas disimpan secara eksplisit.
class ReceivableLine {
  final String description;
  final int qty;
  final int unitPrice;
  /// Tanggal bon/barang, termasuk penambahan bon ke tagihan lama.
  final String entryDate;

  const ReceivableLine({required this.description, required this.qty,
    required this.unitPrice, this.entryDate = ''});

  int get total => qty * unitPrice;

  factory ReceivableLine.fromRow(Map<String, Object?> row) => ReceivableLine(
    description: row['description'] as String,
    qty: (row['qty'] as num).toInt(),
    unitPrice: (row['unit_price'] as num).toInt(),
    entryDate: (row['entry_date'] as String?) ?? '',
  );
}

/// Normalisasi nomor tujuan WhatsApp tanpa mengirimkan pesan.
/// 08... atau 8... diperlakukan sebagai nomor Indonesia; +CC dipertahankan.
String? whatsappPhone(String raw) {
  final input = raw.trim();
  if (input.isEmpty || !RegExp(r'^\+?[0-9\s().-]+$').hasMatch(input)) return null;
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (digits.startsWith('8')) {
    digits = '62$digits';
  }
  if (digits.length < 9 || digits.length > 15 || digits.startsWith('0')) return null;
  return digits;
}

/// Tanggal hanya YYYY-MM-DD yang benar-benar valid (bukan tanggal overflow).
bool validEntryDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final d = DateTime.tryParse(value);
  return d != null && d.toIso8601String().substring(0, 10) == value;
}

class ReceivableSummary {
  final int totalOutstanding;
  final int overdueAmount;
  final int openCount;
  final int alertCount;
  const ReceivableSummary({required this.totalOutstanding, required this.overdueAmount,
    required this.openCount, required this.alertCount});
}

class ReceivablesService {
  ReceivablesService._();
  static Future<List<Receivable>> all() async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('''
      SELECT r.*, COALESCE((SELECT SUM(p.amount)
        FROM receivable_payments p WHERE p.receivable_id = r.id), 0) AS paid
      FROM receivables r ORDER BY r.due_date ASC, r.id DESC
    ''');
    return result.map(Receivable.fromRow).toList();
  }

  static Future<ReceivableSummary> summary() async {
    final rows = await all();
    return ReceivableSummary(
      totalOutstanding: rows.fold(0, (v, r) => v + r.remaining),
      overdueAmount: rows.where((r) => r.overdue).fold(0, (v, r) => v + r.remaining),
      openCount: rows.where((r) => !r.isPaid).length,
      alertCount: rows.where((r) => r.overdue || r.dueSoon).length,
    );
  }

  static Future<int> create({required String customer, required String phone,
    required String description, required int amount, required DateTime dueDate,
    String notes = ''}) async {
    if (customer.trim().isEmpty || description.trim().isEmpty || amount <= 0 || amount > 1000000000) {
      throw const FormatException('Nama, keterangan dan nominal piutang tidak valid');
    }
    final db = await AppDatabase.instance;
    return db.insert('receivables', {
      'customer_name': customer.trim(), 'phone': phone.trim(),
      'description': description.trim(), 'amount': amount,
      'due_date': dueDate.toIso8601String().substring(0, 10),
      'notes': notes.trim(), 'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Mengembalikan baris transaksi. Piutang versi lama boleh tanpa rincian.
  static Future<List<ReceivableLine>> lines(int id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('receivable_items', where: 'receivable_id=?',
      whereArgs: [id], orderBy: 'sort_order ASC, id ASC');
    return rows.map(ReceivableLine.fromRow).toList();
  }

  static int calculateTotal(List<ReceivableLine> lines) {
    if (lines.isEmpty || lines.length > 200) {
      throw const FormatException('Isi 1 sampai 200 baris barang atau jasa');
    }
    var total = 0;
    for (final line in lines) {
      if (line.description.trim().isEmpty || line.description.trim().length > 120 ||
          line.qty <= 0 || line.qty > 10000 ||
          line.unitPrice < 0 || line.unitPrice > 1000000000 ||
          (line.entryDate.isNotEmpty && !validEntryDate(line.entryDate))) {
        throw const FormatException('Nama, jumlah, atau harga barang tidak valid');
      }
      total += line.total;
      if (total > 1000000000) {
        throw const FormatException('Total piutang maksimal Rp1 miliar');
      }
    }
    if (total <= 0) throw const FormatException('Total piutang harus lebih dari Rp0');
    return total;
  }

  static String _date(DateTime date) => date.toIso8601String().substring(0, 10);

  static Future<int> createDetailed({required String customer,
    required String phone, required String description, required DateTime dueDate,
    required List<ReceivableLine> lines, String notes = ''}) async {
    final total = calculateTotal(lines);
    if (customer.trim().isEmpty || customer.trim().length > 120 ||
        description.trim().isEmpty || description.trim().length > 500) {
      throw const FormatException('Isi nama pelanggan dan ringkasan transaksi');
    }
    final db = await AppDatabase.instance;
    return db.transaction<int>((txn) async {
      final id = await txn.insert('receivables', {
        'customer_name': customer.trim(), 'phone': phone.trim(),
        'description': description.trim(), 'amount': total,
        'due_date': _date(dueDate), 'notes': notes.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      final nowDate = _date(DateTime.now());
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        await txn.insert('receivable_items', {
          'receivable_id': id, 'description': line.description.trim(),
          'qty': line.qty, 'unit_price': line.unitPrice, 'total': line.total,
          'sort_order': i, 'entry_date': line.entryDate.isEmpty ? nowDate : line.entryDate,
        });
      }
      return id;
    });
  }

  /// Perbarui identitas/rincian secara atomik. Tidak pernah menghapus cicilan.
  /// Total baru harus >= pembayaran yang sudah tercatat.
  static Future<void> editDetailed({required int receivableId,
    required String customer, required String phone, required String description,
    required String notes, required DateTime dueDate,
    required List<ReceivableLine> lines}) async {
    final total = calculateTotal(lines);
    if (customer.trim().isEmpty || customer.trim().length > 120 ||
        description.trim().isEmpty || description.trim().length > 500) {
      throw const FormatException('Nama dan ringkasan transaksi wajib diisi');
    }
    final db = await AppDatabase.instance;
    await db.transaction<void>((txn) async {
      final existing = await txn.query('receivables', where: 'id=?',
        whereArgs: [receivableId], limit: 1);
      if (existing.isEmpty) throw StateError('Piutang tidak ditemukan');
      final result = await txn.rawQuery('SELECT COALESCE(SUM(amount),0) AS paid FROM receivable_payments WHERE receivable_id=?', [receivableId]);
      final paid = (result.single['paid'] as num).toInt();
      if (total < paid) {
        throw StateError('Total baru tidak boleh kurang dari cicilan tercatat');
      }
      await txn.update('receivables', {
        'customer_name': customer.trim(), 'phone': phone.trim(),
        'description': description.trim(), 'notes': notes.trim(),
        'amount': total, 'due_date': _date(dueDate),
      }, where: 'id=?', whereArgs: [receivableId]);
      await txn.delete('receivable_items', where: 'receivable_id=?',
        whereArgs: [receivableId]);
      final nowDate = _date(DateTime.now());
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        await txn.insert('receivable_items', {
          'receivable_id': receivableId, 'description': line.description.trim(),
          'qty': line.qty, 'unit_price': line.unitPrice,
          'total': line.total, 'sort_order': i,
          'entry_date': line.entryDate.isEmpty ? nowDate : line.entryDate,
        });
      }
    });
  }

  static Future<void> recordPayment({required int receivableId,
    required int amount, required String method, String note = ''}) async {
    if (amount <= 0 || amount > 1000000000) throw const FormatException('Nominal tidak valid');
    if (!const ['Tunai', 'Transfer', 'E-Wallet'].contains(method)) {
      throw const FormatException('Metode pembayaran tidak dikenal');
    }
    final db = await AppDatabase.instance;
    await db.transaction<void>((txn) async {
      final items = await txn.query('receivables', where: 'id=?', whereArgs: [receivableId], limit: 1);
      if (items.isEmpty) throw StateError('Piutang tidak ditemukan');
      final principal = (items.single['amount'] as num).toInt();
      final result = await txn.rawQuery('''SELECT COALESCE(SUM(amount),0) AS paid
        FROM receivable_payments WHERE receivable_id=?''', [receivableId]);
      final paid = (result.single['paid'] as num).toInt();
      if (amount > principal - paid) throw StateError('Pembayaran melebihi sisa piutang');
      await txn.insert('receivable_payments', {
        'receivable_id': receivableId, 'amount': amount, 'method': method,
        'note': note.trim(), 'paid_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Bon baru dalam piutang yang sama; jumlah sudah dibayar tidak berubah.
  /// Setiap item dicatat beserta tanggal bon dan aktivitasnya.
  static Future<void> appendBon({required int receivableId,
    required List<ReceivableLine> lines, DateTime? dueDate}) async {
    final additional = calculateTotal(lines);
    final db = await AppDatabase.instance;
    await db.transaction<void>((txn) async {
      final found = await txn.query('receivables', where: 'id=?',
        whereArgs: [receivableId], limit: 1);
      if (found.isEmpty) throw StateError('Piutang pelanggan tidak ditemukan');
      final previous = (found.single['amount'] as num).toInt();
      if (previous + additional > 1000000000) {
        throw StateError('Total gabungan maksimal Rp1 miliar');
      }
      final existingCount = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM receivable_items WHERE receivable_id=?',
        [receivableId]);
      // Piutang sebelum versi rincian hanya memiliki nominal induk.
      // Sertakan item historis agar nota tetap menjumlah dengan benar.
      if ((existingCount.single['count'] as num).toInt() == 0) {
        final old = found.single;
        await txn.insert('receivable_items', {
          'receivable_id': receivableId,
          'description': old['description'], 'qty': 1,
          'unit_price': previous, 'total': previous,
          'sort_order': 0,
          'entry_date': '${old['created_at']}'.substring(0, 10),
        });
      }
      final maxRow = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS last_row FROM receivable_items WHERE receivable_id=?',
        [receivableId]);
      final start = (maxRow.single['last_row'] as num).toInt() + 1;
      final today = _date(DateTime.now());
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        await txn.insert('receivable_items', {
          'receivable_id': receivableId, 'description': line.description.trim(),
          'qty': line.qty, 'unit_price': line.unitPrice, 'total': line.total,
          'sort_order': start + i,
          'entry_date': line.entryDate.isEmpty ? today : line.entryDate,
        });
      }
      await txn.update('receivables', {
        'amount': previous + additional,
        if (dueDate != null) 'due_date': _date(dueDate),
      },
        where: 'id=?', whereArgs: [receivableId]);
      await txn.insert('receivable_bon_events', {
        'receivable_id': receivableId, 'action': 'bon_added',
        'amount': additional, 'item_count': lines.length,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  static Future<List<Map<String, Object?>>> bonEvents(int id) async {
    final db = await AppDatabase.instance;
    return db.query('receivable_bon_events', where: 'receivable_id=?',
      whereArgs: [id], orderBy: 'id DESC', limit: 50);
  }

  /// Koreksi pembayaran memakai transaksi: validasi saldo dan log audit
  /// terjadi atomik. Tidak menghapus rekam jejak nominal sebelumnya.
  static Future<void> editPayment({required int receivableId,
    required int paymentId, required int amount, required String method,
    required String note, required DateTime paidAt,
    required String reason}) async {
    if (amount <= 0 || amount > 1000000000) {
      throw const FormatException('Nominal harus lebih besar dari Rp0');
    }
    if (!const ['Tunai', 'Transfer', 'E-Wallet'].contains(method)) {
      throw const FormatException('Metode pembayaran tidak valid');
    }
    if (reason.trim().length < 5 || reason.trim().length > 300) {
      throw const FormatException('Tulis alasan koreksi minimal 5 karakter');
    }
    if (note.length > 500) throw const FormatException('Catatan terlalu panjang');
    final now = DateTime.now();
    if (paidAt.isAfter(now.add(const Duration(days: 1))) ||
        paidAt.isBefore(DateTime(2020))) {
      throw const FormatException('Tanggal pembayaran tidak valid');
    }
    final db = await AppDatabase.instance;
    await db.transaction<void>((txn) async {
      final debts = await txn.query('receivables', where: 'id=?',
        whereArgs: [receivableId], limit: 1);
      if (debts.isEmpty) throw StateError('Piutang tidak ditemukan');
      final rows = await txn.query('receivable_payments',
        where: 'id=? AND receivable_id=?',
        whereArgs: [paymentId, receivableId], limit: 1);
      if (rows.isEmpty) throw StateError('Riwayat pembayaran tidak ditemukan');
      final old = rows.single;
      final others = await txn.rawQuery('''SELECT COALESCE(SUM(amount),0) AS total
        FROM receivable_payments WHERE receivable_id=? AND id<>?''',
        [receivableId, paymentId]);
      final otherPaid = (others.single['total'] as num).toInt();
      final principal = (debts.single['amount'] as num).toInt();
      if (otherPaid + amount > principal) {
        throw StateError('Koreksi melebihi total piutang. Maksimal ${principal - otherPaid}');
      }
      final nextPaidAt = paidAt.toIso8601String();
      final nextNote = note.trim();
      if (old['amount'] == amount && old['method'] == method &&
          old['note'] == nextNote && old['paid_at'] == nextPaidAt) {
        throw StateError('Tidak ada perubahan pada pembayaran');
      }
      await txn.update('receivable_payments', {
        'amount': amount, 'method': method, 'note': nextNote,
        'paid_at': nextPaidAt,
      }, where: 'id=? AND receivable_id=?',
        whereArgs: [paymentId, receivableId]);
      await txn.insert('receivable_payment_edits', {
        'receivable_id': receivableId, 'payment_id': paymentId,
        'old_amount': old['amount'], 'new_amount': amount,
        'old_method': old['method'], 'new_method': method,
        'old_note': old['note'], 'new_note': nextNote,
        'old_paid_at': old['paid_at'], 'new_paid_at': nextPaidAt,
        'reason': reason.trim(), 'edited_at': now.toIso8601String(),
      });
    });
  }

  static Future<List<Map<String, Object?>>> paymentEdits(int id) async {
    final db = await AppDatabase.instance;
    return db.query('receivable_payment_edits', where: 'receivable_id=?',
      whereArgs: [id], orderBy: 'id DESC', limit: 100);
  }

  static Future<void> updateDueDate(int id, DateTime date) async {
    final db = await AppDatabase.instance;
    await db.update('receivables', {'due_date': date.toIso8601String().substring(0, 10)},
      where: 'id=?', whereArgs: [id]);
  }

  static Future<List<Map<String, Object?>>> payments(int id) async {
    final db = await AppDatabase.instance;
    return db.query('receivable_payments', where: 'receivable_id=?',
      whereArgs: [id], orderBy: 'paid_at DESC');
  }
}
