import 'package:sqflite/sqflite.dart';

import '../core/database.dart';

/// Additional operational features. All SQL values are bound parameters.
class StorePlusService {
  StorePlusService._();

  static const categories = <String>[
    'Umum', 'Belanja', 'Service', 'Pelanggan', 'Tagihan', 'Operasional',
  ];
  static const priorities = <String>['Rendah', 'Normal', 'Tinggi'];
  static const statuses = <String>['Selesai', 'Menunggu', 'Gagal'];

  static Future<List<Map<String, Object?>>> notes() async =>
      (await AppDatabase.instance).query('store_notes',
          orderBy: 'pinned DESC, done ASC, due_at ASC, id DESC');

  static Future<void> saveNote({int? id, required String text,
    required String category, required String priority,
    String dueAt = '', bool pinned = false}) async {
    final content = text.trim();
    if (content.isEmpty || content.length > 500) {
      throw const FormatException('Catatan wajib diisi (maksimal 500 karakter).');
    }
    if (!categories.contains(category) || !priorities.contains(priority)) {
      throw const FormatException('Kategori atau prioritas tidak valid.');
    }
    if (dueAt.isNotEmpty && (DateTime.tryParse(dueAt) == null || dueAt.length != 10)) {
      throw const FormatException('Tanggal tenggat tidak valid.');
    }
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final fields = <String, Object?>{
      'text': content, 'category': category, 'priority': priority,
      'due_at': dueAt, 'pinned': pinned ? 1 : 0, 'updated_at': now,
    };
    if (id == null) {
      await db.insert('store_notes', {...fields, 'done': 0, 'created_at': now});
    } else {
      final count = await db.update('store_notes', fields, where: 'id=?', whereArgs: [id]);
      if (count != 1) throw StateError('Catatan tidak ditemukan.');
    }
  }

  static Future<void> setNoteDone(int id, bool done) async {
    await (await AppDatabase.instance).update('store_notes',
        {'done': done ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id=?', whereArgs: [id]);
  }

  static Future<void> removeNote(int id) async {
    await (await AppDatabase.instance).delete('store_notes', where: 'id=?', whereArgs: [id]);
  }

  static Future<List<Map<String, Object?>>> digital() async =>
      (await AppDatabase.instance).query('digital_transactions', orderBy: 'id DESC');

  static Future<void> addDigital({required String service, required String destination,
      required int nominal, required int fee, required String status,
      required String method, required String note, required String reference}) async {
    _validateDigital(service, destination, nominal, fee, status, method, note, reference);
    await (await AppDatabase.instance).insert('digital_transactions', {
      'operator': service.trim(), 'destination': destination.trim(),
      'nominal': nominal, 'fee': fee, 'status': status, 'payment_method': method,
      'note': note.trim(), 'reference_code': reference.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static void _validateDigital(String service, String destination, int nominal,
      int fee, String status, String method, String note, String reference) {
    if (service.trim().isEmpty || destination.trim().isEmpty ||
        service.length > 80 || destination.length > 120 || nominal <= 0 ||
        nominal > 1000000000 || fee < 0 || fee > 100000000 ||
        !statuses.contains(status) || method.trim().isEmpty ||
        note.length > 500 || reference.length > 100) {
      throw const FormatException('Periksa data transaksi, nominal, status, dan catatan.');
    }
  }

  /// Only metadata is editable: the historical nominal/admin charge stays intact.
  /// All status/notes edits have an audit record within the same transaction.
  static Future<void> updateDigital(int id, {required String status,
    required String note, required String reference}) async {
    if (!statuses.contains(status) || note.length > 500 || reference.length > 100) {
      throw const FormatException('Status atau catatan tidak valid.');
    }
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final old = await txn.query('digital_transactions', where: 'id=?',
        whereArgs: [id], limit: 1);
      if (old.isEmpty) throw StateError('Transaksi tidak ditemukan.');
      final prior = old.first;
      final now = DateTime.now().toIso8601String();
      await txn.update('digital_transactions', {
        'status': status, 'note': note.trim(), 'reference_code': reference.trim(),
      }, where: 'id=?', whereArgs: [id]);
      await txn.insert('digital_events', {
        'transaction_id': id,
        'old_status': prior['status'] ?? 'Selesai',
        'new_status': status,
        'old_note': prior['note'] ?? '',
        'new_note': note.trim(),
        'old_reference': prior['reference_code'] ?? '',
        'new_reference': reference.trim(),
        'created_at': now,
      });
    });
  }

  static Future<List<Map<String, Object?>>> digitalEvents(int id) async =>
      (await AppDatabase.instance).query('digital_events', where: 'transaction_id=?',
        whereArgs: [id], orderBy: 'id DESC');

  static Future<List<Map<String, Object?>>> cashMovements() async =>
      (await AppDatabase.instance).query('cash_adjustments', orderBy: 'id DESC');

  static Future<Map<String, int>> cashStats() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''SELECT
      COALESCE(SUM(CASE WHEN delta>0 THEN delta ELSE 0 END),0) AS incoming,
      COALESCE(SUM(CASE WHEN delta<0 THEN -delta ELSE 0 END),0) AS outgoing,
      COUNT(*) AS count FROM cash_adjustments''');
    final row = rows.first;
    return {'incoming': (row['incoming'] as num).toInt(),
      'outgoing': (row['outgoing'] as num).toInt(),
      'count': (row['count'] as num).toInt()};
  }

  /// Date-bounded operational report. Fees count COMPLETED digital transactions.
  /// Not a bank reconciliation or tax accounting statement.
  static Future<Map<String, int>> report(DateTime start, DateTime end) async {
    final db = await AppDatabase.instance;
    final from = start.toIso8601String().substring(0, 10);
    final until = end.add(const Duration(days: 1)).toIso8601String().substring(0, 10);
    if (from.compareTo(until) >= 0) throw const FormatException('Periode laporan tidak valid.');
    Future<int> sum(String table, String col, {String extra = ''}) async {
      final rows = await db.rawQuery('SELECT COALESCE(SUM($col),0) AS n FROM $table '
        'WHERE created_at >= ? AND created_at < ? $extra', [from, until]);
      return (rows.first['n'] as num).toInt();
    }
    final sales = await sum('sales', 'total');
    final receipts = await sum('receipts', 'total');
    final legacyProfit = await sum('sales', 'profit');
    final r = await db.rawQuery('''SELECT COALESCE(SUM(
      (ri.unit_price-ri.unit_cost)*ri.qty),0) AS gross
      FROM receipt_items ri JOIN receipts r ON r.id=ri.receipt_id
      WHERE r.created_at>=? AND r.created_at<?''', [from, until]);
    final profit = legacyProfit + (r.first['gross'] as num).toInt()
        - await sum('receipts', 'discount');
    final fees = await sum('digital_transactions', 'fee',
        extra: "AND status='Selesai'");
    final expenses = await sum('expenses', 'amount');
    return {'revenue': sales + receipts, 'profit': profit, 'fees': fees,
      'expenses': expenses, 'net': profit + fees - expenses};
  }

  static Future<Map<String, int>> inventoryStats() async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('''SELECT COUNT(*) AS items,
      COALESCE(SUM(stock),0) AS units,
      COALESCE(SUM(stock*cost),0) AS capital,
      COALESCE(SUM(stock*price),0) AS selling,
      COALESCE(SUM(CASE WHEN stock<=min_stock THEN 1 ELSE 0 END),0) AS low,
      COALESCE(SUM(CASE WHEN stock=0 THEN 1 ELSE 0 END),0) AS empty
      FROM products''');
    return result.first.map((key, value) => MapEntry(key, (value as num).toInt()));
  }
}
