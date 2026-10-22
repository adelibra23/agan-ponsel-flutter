import 'package:sqflite/sqflite.dart';
import '../core/database.dart';

/// Expense changes are transactionally recorded and do not change historical
/// sales/service tables. Amounts are integer rupiah to avoid rounding errors.
class ExpenseCategory {
  final int id;
  final String name;
  final bool archived;
  const ExpenseCategory(this.id, this.name, this.archived);
  factory ExpenseCategory.from(Map<String, Object?> row) => ExpenseCategory(
    row['id'] as int, row['name'] as String, (row['archived'] as int? ?? 0) == 1);
}

class ExpenseEntry {
  final int id;
  final String description;
  final String note;
  final String method;
  final String category;
  final int? categoryId;
  final int amount;
  final DateTime date;
  final String updatedAt;
  const ExpenseEntry({required this.id, required this.description,
    required this.note, required this.method, required this.category,
    required this.categoryId, required this.amount, required this.date,
    required this.updatedAt});

  factory ExpenseEntry.from(Map<String, Object?> row) => ExpenseEntry(
    id: row['id'] as int,
    description: row['description'] as String,
    note: row['note'] as String? ?? '',
    method: row['payment_method'] as String? ?? 'Tunai',
    category: row['category_name'] as String? ?? 'Lainnya',
    categoryId: row['category_id'] as int?,
    amount: (row['amount'] as num).toInt(),
    date: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt: row['updated_at'] as String? ?? '',
  );
}

class ExpensesService {
  ExpensesService._();

  static String _now() => DateTime.now().toIso8601String();
  static const methods = ['Tunai', 'Transfer', 'E-Wallet', 'Lainnya'];

  static void _validate({required String description, required int amount,
    required DateTime when, required String method}) {
    if (description.trim().isEmpty || description.trim().length > 120) {
      throw const FormatException('Keterangan wajib 1–120 karakter');
    }
    if (amount <= 0 || amount > 1000000000000) {
      throw const FormatException('Nominal harus antara Rp1 dan Rp1 triliun');
    }
    if (!methods.contains(method)) throw const FormatException('Metode pembayaran tidak dikenal');
    if (when.year < 2000 || when.isAfter(DateTime.now().add(const Duration(days: 366)))) {
      throw const FormatException('Tanggal transaksi tidak valid');
    }
  }

  static Future<List<ExpenseCategory>> categories({bool showArchived = false}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('expense_categories',
      where: showArchived ? null : 'archived = 0', orderBy: 'name COLLATE NOCASE');
    return rows.map(ExpenseCategory.from).toList();
  }

  static Future<int> addCategory(String text) async {
    final name = text.trim();
    if (name.length < 2 || name.length > 35) {
      throw const FormatException('Nama kategori harus 2–35 karakter');
    }
    final db = await AppDatabase.instance;
    final matches = await db.query('expense_categories',
      columns: ['id','archived'], where: 'name = ? COLLATE NOCASE', whereArgs: [name], limit: 1);
    if (matches.isNotEmpty) {
      if ((matches.first['archived'] as int? ?? 0) == 1) {
        await db.update('expense_categories', {'archived': 0},
          where: 'id = ?', whereArgs: [matches.first['id']]);
      }
      return matches.first['id'] as int;
    }
    return db.insert('expense_categories', {'name': name, 'archived': 0,
      'created_at': _now()});
  }

  static Future<void> renameCategory(int id, String text) async {
    final name = text.trim();
    if (name.length < 2 || name.length > 35) {
      throw const FormatException('Nama kategori harus 2–35 karakter');
    }
    final db = await AppDatabase.instance;
    final old = await db.query('expense_categories', where: 'id=?', whereArgs: [id], limit: 1);
    if (old.isEmpty) throw StateError('Kategori tidak ditemukan');
    if ((old.first['name'] as String).toLowerCase() == 'lainnya') {
      throw StateError('Kategori utama Lainnya tidak dapat diganti');
    }
    final duplicate = await db.query('expense_categories', columns: ['id'],
      where: 'name=? COLLATE NOCASE AND id<>?', whereArgs: [name, id], limit: 1);
    if (duplicate.isNotEmpty) throw StateError('Nama kategori sudah terdaftar');
    await db.update('expense_categories', {'name': name}, where: 'id=?', whereArgs: [id]);
  }

  static Future<List<Map<String, Object?>>> auditAll() async {
    return (await AppDatabase.instance).query('expense_audit', orderBy: 'id DESC', limit: 200);
  }

  static Future<void> archiveCategory(int id, {required bool archived}) async {
    final db = await AppDatabase.instance;
    final row = await db.query('expense_categories', where: 'id=?', whereArgs: [id], limit: 1);
    if (row.isEmpty) throw StateError('Kategori tidak ditemukan');
    if ((row.first['name'] as String).toLowerCase() == 'lainnya') {
      throw StateError('Kategori Lainnya tidak boleh diarsipkan');
    }
    await db.update('expense_categories', {'archived': archived ? 1 : 0},
      where: 'id=?', whereArgs: [id]);
  }

  static Future<List<ExpenseEntry>> list() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT e.*, COALESCE(c.name, 'Lainnya') AS category_name
      FROM expenses e LEFT JOIN expense_categories c ON c.id=e.category_id
      ORDER BY e.created_at DESC, e.id DESC
    ''');
    return rows.map(ExpenseEntry.from).toList();
  }

  static Future<ExpenseEntry?> find(int id) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT e.*, COALESCE(c.name, 'Lainnya') AS category_name
      FROM expenses e LEFT JOIN expense_categories c ON c.id=e.category_id
      WHERE e.id=? LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : ExpenseEntry.from(rows.first);
  }

  static Future<List<Map<String, Object?>>> audit(int expenseId) async {
    return (await AppDatabase.instance).query('expense_audit',
      where: 'expense_id=?', whereArgs: [expenseId], orderBy: 'id DESC');
  }

  static Future<void> _checkCategory(Transaction tx, int? categoryId,
      {bool allowArchived = false}) async {
    if (categoryId == null) return;
    final rows = await tx.query('expense_categories', columns: ['id'],
      where: allowArchived ? 'id=?' : 'id=? AND archived=0',
      whereArgs: [categoryId], limit: 1);
    if (rows.isEmpty) throw StateError('Kategori sudah tidak aktif');
  }

  static Future<int> create({required String description, required int amount,
    required DateTime date, required int? categoryId, required String method,
    String note = ''}) async {
    _validate(description: description, amount: amount, when: date, method: method);
    if (note.length > 500) throw const FormatException('Catatan maksimum 500 karakter');
    final db = await AppDatabase.instance;
    return db.transaction<int>((tx) async {
      await _checkCategory(tx, categoryId);
      final id = await tx.insert('expenses', {
        'description': description.trim(), 'amount': amount,
        'category_id': categoryId, 'payment_method': method,
        'note': note.trim(), 'created_at': date.toIso8601String(),
        'updated_at': _now(),
      });
      await tx.insert('expense_audit', {
        'expense_id': id, 'action': 'create', 'old_amount': 0,
        'new_amount': amount, 'reason': 'Pencatatan baru', 'occurred_at': _now(),
        'snapshot': description.trim(),
      });
      return id;
    });
  }

  static Future<void> edit(int id, {required String description, required int amount,
    required DateTime date, required int? categoryId, required String method,
    required String note, required String reason}) async {
    _validate(description: description, amount: amount, when: date, method: method);
    if (note.length > 500) throw const FormatException('Catatan maksimum 500 karakter');
    if (reason.trim().length < 4) throw const FormatException('Alasan koreksi minimal 4 karakter');
    final db = await AppDatabase.instance;
    await db.transaction((tx) async {
      final rows = await tx.query('expenses', where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('Pengeluaran tidak ditemukan');
      final old = rows.first;
      await _checkCategory(tx, categoryId,
        allowArchived: old['category_id'] == categoryId);
      final changed = old['description'] != description.trim() ||
        old['amount'] != amount || old['created_at'] != date.toIso8601String() ||
        old['category_id'] != categoryId || (old['payment_method'] ?? 'Tunai') != method ||
        (old['note'] ?? '') != note.trim();
      if (!changed) throw StateError('Tidak ada data yang berubah');
      await tx.update('expenses', {
        'description': description.trim(), 'amount': amount,
        'created_at': date.toIso8601String(), 'category_id': categoryId,
        'payment_method': method, 'note': note.trim(), 'updated_at': _now(),
      }, where: 'id=?', whereArgs: [id]);
      await tx.insert('expense_audit', {
        'expense_id': id, 'action': 'edit', 'old_amount': old['amount'],
        'new_amount': amount, 'reason': reason.trim(), 'occurred_at': _now(),
        'snapshot': 'SEBELUM: ${old['description']} | ${old['created_at']} | '
          '${old['payment_method']} | kategori ${old['category_id']} | ${old['note']}\n'
          'SESUDAH: ${description.trim()} | ${date.toIso8601String()} | '
          '$method | kategori $categoryId | ${note.trim()}',
      });
    });
  }

  static Future<void> delete(int id, {required String reason}) async {
    if (reason.trim().length < 4) throw const FormatException('Alasan penghapusan minimal 4 karakter');
    final db = await AppDatabase.instance;
    await db.transaction((tx) async {
      final rows = await tx.query('expenses', where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('Pengeluaran tidak ditemukan');
      final old = rows.first;
      await tx.insert('expense_audit', {
        'expense_id': id, 'action': 'delete', 'old_amount': old['amount'],
        'new_amount': 0, 'reason': reason.trim(), 'occurred_at': _now(),
        'snapshot': '${old['description']} | ${old['created_at']} | ${old['note']}',
      });
      await tx.delete('expenses', where: 'id=?', whereArgs: [id]);
    });
  }
}
