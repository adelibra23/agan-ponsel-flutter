import '../core/database.dart';

/// Restock is a planning ledger. It never records expenses or changes stock
/// until the owner explicitly confirms receipt of a draft purchase order.
class SupplierEntry {
  final int id;
  final String name;
  final String phone;
  final String address;
  final String note;

  const SupplierEntry({required this.id, required this.name, required this.phone,
    required this.address, required this.note});

  factory SupplierEntry.from(Map<String, Object?> row) => SupplierEntry(
    id: row['id'] as int,
    name: row['name'] as String,
    phone: row['phone'] as String? ?? '',
    address: row['address'] as String? ?? '',
    note: row['note'] as String? ?? '',
  );
}

class RestockDraftLine {
  final Product product;
  final int qty;
  const RestockDraftLine(this.product, this.qty);
  int get estimatedCost => qty * product.cost;
}

class RestockOrder {
  final int id;
  final int? supplierId;
  final String supplierName;
  final String status;
  final String note;
  final String createdAt;
  final String receivedAt;
  final int estimatedTotal;

  const RestockOrder({required this.id, required this.supplierId,
    required this.supplierName, required this.status, required this.note,
    required this.createdAt, required this.receivedAt,
    required this.estimatedTotal});

  factory RestockOrder.from(Map<String, Object?> r) => RestockOrder(
    id: r['id'] as int,
    supplierId: r['supplier_id'] as int?,
    supplierName: r['supplier_name'] as String? ?? '',
    status: r['status'] as String,
    note: r['notes'] as String? ?? '',
    createdAt: r['created_at'] as String,
    receivedAt: r['received_at'] as String? ?? '',
    estimatedTotal: (r['estimated_total'] as num).toInt(),
  );
}

class RestockOrderLine {
  final int productId;
  final String productName;
  final int qty;
  final int unitCost;
  const RestockOrderLine({required this.productId,
    required this.productName, required this.qty, required this.unitCost});
  int get total => qty * unitCost;
  factory RestockOrderLine.from(Map<String, Object?> r) => RestockOrderLine(
    productId: r['product_id'] as int,
    productName: r['product_name'] as String,
    qty: (r['qty'] as num).toInt(),
    unitCost: (r['unit_cost'] as num).toInt(),
  );
}

class RestockService {
  RestockService._();

  static int suggestedQty(int stock, int minimum) {
    if (stock > minimum) return 0;
    final target = minimum <= 0 ? 1 : minimum * 2;
    return (target - stock).clamp(1, 9999).toInt();
  }

  static int estimateCost(List<RestockDraftLine> lines) =>
    lines.fold<int>(0, (sum, line) => sum + line.estimatedCost);

  static Future<List<Product>> lowStockProducts() async {
    final products = await AppDatabase.products();
    final low = products.where((p) => p.stock <= p.minStock).toList();
    low.sort((a, b) => (a.stock - a.minStock).compareTo(b.stock - b.minStock));
    return low;
  }

  static Future<List<SupplierEntry>> suppliers() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('suppliers', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(SupplierEntry.from).toList();
  }

  static Future<int> saveSupplier({int? id, required String name,
    String phone = '', String address = '', String note = ''}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw StateError('Nama supplier wajib diisi.');
    if (clean.length > 100) throw StateError('Nama supplier terlalu panjang.');
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'name': clean,
      'phone': phone.trim(),
      'address': address.trim(),
      'note': note.trim(),
      'updated_at': now,
    };
    if (id == null) {
      data['created_at'] = now;
      return db.insert('suppliers', data);
    }
    final changed = await db.update('suppliers', data,
      where: 'id=?', whereArgs: [id]);
    if (changed != 1) throw StateError('Supplier tidak ditemukan.');
    return id;
  }

  static Future<List<RestockOrder>> orders() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''SELECT o.*,
      COALESCE(s.name, '') AS supplier_name
      FROM restock_orders AS o
      LEFT JOIN suppliers AS s ON s.id=o.supplier_id
      ORDER BY o.id DESC''');
    return rows.map(RestockOrder.from).toList();
  }

  static Future<List<RestockOrderLine>> orderLines(int orderId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('restock_order_items',
      where: 'order_id=?', whereArgs: [orderId], orderBy: 'id ASC');
    return rows.map(RestockOrderLine.from).toList();
  }

  static Future<int> createOrder({int? supplierId, required String note,
    required List<RestockDraftLine> lines}) async {
    if (lines.isEmpty) throw StateError('Pilih setidaknya satu produk.');
    if (lines.length > 100) throw StateError('Maksimal 100 produk per rencana.');
    final ids = <int>{};
    for (final line in lines) {
      if (line.qty < 1 || line.qty > 9999) {
        throw StateError('Jumlah barang harus 1–9999.');
      }
      if (!ids.add(line.product.id)) {
        throw StateError('Produk ganda dalam rencana restock.');
      }
    }
    final db = await AppDatabase.instance;
    return db.transaction<int>((txn) async {
      if (supplierId != null) {
        final found = await txn.query('suppliers', columns: ['id'],
          where: 'id=?', whereArgs: [supplierId], limit: 1);
        if (found.isEmpty) throw StateError('Supplier tidak ditemukan.');
      }
      final stored = <RestockOrderLine>[];
      for (final line in lines) {
        final rows = await txn.query('products',
          columns: ['id', 'name', 'cost'],
          where: 'id=?', whereArgs: [line.product.id], limit: 1);
        if (rows.isEmpty) throw StateError('Produk telah dihapus: ${line.product.name}');
        stored.add(RestockOrderLine(
          productId: line.product.id,
          productName: rows.first['name'] as String,
          qty: line.qty,
          unitCost: (rows.first['cost'] as num).toInt(),
        ));
      }
      final total = stored.fold<int>(0, (sum, line) => sum + line.total);
      final id = await txn.insert('restock_orders', {
        'supplier_id': supplierId,
        'status': 'draft',
        'notes': note.trim(),
        'estimated_total': total,
        'created_at': DateTime.now().toIso8601String(),
        'received_at': '',
      });
      for (final line in stored) {
        await txn.insert('restock_order_items', {
          'order_id': id,
          'product_id': line.productId,
          'product_name': line.productName,
          'qty': line.qty,
          'unit_cost': line.unitCost,
        });
      }
      return id;
    });
  }

  /// Receipt is atomic and idempotency-guarded by the draft state.
  /// A second call fails without adding inventory twice.
  static Future<void> receiveOrder(int orderId) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final orders = await txn.query('restock_orders',
        where: 'id=?', whereArgs: [orderId], limit: 1);
      if (orders.isEmpty) throw StateError('Rencana restock tidak ditemukan.');
      if (orders.first['status'] != 'draft') {
        throw StateError('Rencana ini sudah selesai atau dibatalkan.');
      }
      final items = await txn.query('restock_order_items',
        where: 'order_id=?', whereArgs: [orderId]);
      if (items.isEmpty) throw StateError('Rencana tidak memiliki barang.');
      // Validate ALL referenced products before mutating any stock.
      for (final item in items) {
        final matches = await txn.query('products', columns: ['id'],
          where: 'id=?', whereArgs: [item['product_id']], limit: 1);
        if (matches.isEmpty) {
          throw StateError('Produk ${item['product_name']} tidak tersedia.');
        }
      }
      final timestamp = DateTime.now().toIso8601String();
      for (final item in items) {
        final qty = (item['qty'] as num).toInt();
        if (qty <= 0) throw StateError('Jumlah restock tidak valid.');
        await txn.rawUpdate('UPDATE products SET stock=stock+? WHERE id=?',
          [qty, item['product_id']]);
        await txn.insert('stock_movements', {
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'delta': qty,
          'note': 'Restock #$orderId • barang diterima',
          'created_at': timestamp,
        });
      }
      await txn.update('restock_orders', {
        'status': 'received', 'received_at': timestamp,
      }, where: 'id=? AND status=?', whereArgs: [orderId, 'draft']);
    });
  }

  static Future<void> cancelOrder(int orderId) async {
    final db = await AppDatabase.instance;
    final changed = await db.update('restock_orders', {'status': 'cancelled'},
      where: 'id=? AND status=?', whereArgs: [orderId, 'draft']);
    if (changed != 1) throw StateError('Hanya rencana baru yang dapat dibatalkan.');
  }
}
