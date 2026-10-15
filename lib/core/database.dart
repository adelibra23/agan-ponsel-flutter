import 'format.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Product {
  final int id;
  final String name;
  final String category;
  final String sku;
  final String photoFile;
  final int stock;
  final int minStock;
  final int cost;
  final int price;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.sku,
    this.photoFile = '',
    required this.stock,
    required this.minStock,
    required this.cost,
    required this.price,
  });

  factory Product.from(Map<String, Object?> v) => Product(
        id: v['id'] as int,
        name: v['name'] as String,
        category: v['category'] as String? ?? 'Aksesoris',
        sku: v['sku'] as String? ?? '',
        photoFile: v['photo_file'] as String? ?? '',
        stock: v['stock'] as int,
        minStock: v['min_stock'] as int? ?? 5,
        cost: v['cost'] as int,
        price: v['price'] as int,
      );
}

class CartItem {
  Product product;
  int quantity;
  CartItem(this.product, [this.quantity = 1]);
  int get total => product.price * quantity;
}

class SaleResult {
  final int id;
  final String code;
  final int subtotal;
  final int discount;
  final int total;
  final int paid;
  final int change;
  final String method;
  final String createdAt;
  final List<CartItem> items;
  const SaleResult({
    required this.id,
    required this.code,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paid,
    required this.change,
    required this.method,
    required this.createdAt,
    required this.items,
  });
}

class AppDatabase {
  AppDatabase._();
  static Future<Database>? _opening;
  static Future<Database> get instance => _opening ??= _open();

  static Future<Database> _open() async {
    // Same database filename as Flutter v0.2. Existing local data is migrated.
    final path = p.join(await getDatabasesPath(), 'agan_ponsel_v1.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createBase(db);
        await _createNew(db);
        await _createServiceExtras(db);
        await _createPhotoExtras(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createExtra(db);
        }
        if (oldVersion < 3) {
          await _addProductFields(db);
          await _createNew(db);
        }
        if (oldVersion < 4) {
          await _createServiceExtras(db);
        }
        if (oldVersion < 5) {
          await _createPhotoExtras(db);
        }
      },
    );
  }

  static Future<void> _createBase(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, stock INTEGER NOT NULL DEFAULT 0, cost INTEGER NOT NULL DEFAULT 0, price INTEGER NOT NULL DEFAULT 0, category TEXT NOT NULL DEFAULT \'Aksesoris\', sku TEXT NOT NULL DEFAULT \'\', min_stock INTEGER NOT NULL DEFAULT 5)');
    await db.execute('CREATE TABLE IF NOT EXISTS sales(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL, name TEXT NOT NULL, qty INTEGER NOT NULL, total INTEGER NOT NULL, profit INTEGER NOT NULL, created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS services(id INTEGER PRIMARY KEY AUTOINCREMENT, customer TEXT NOT NULL, phone TEXT NOT NULL, device TEXT NOT NULL, issue TEXT NOT NULL, fee INTEGER NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL)');
    await _createExtra(db);
  }

  static Future<void> _createExtra(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT NOT NULL, note TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, amount INTEGER NOT NULL, created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS digital_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, operator TEXT NOT NULL, destination TEXT NOT NULL, nominal INTEGER NOT NULL, fee INTEGER NOT NULL, created_at TEXT NOT NULL)');
  }

  static Future<void> _addProductFields(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(products)'))
        .map((row) => row['name'] as String).toSet();
    if (!columns.contains('category')) {
      await db.execute("ALTER TABLE products ADD COLUMN category TEXT NOT NULL DEFAULT 'Aksesoris'");
    }
    if (!columns.contains('sku')) {
      await db.execute("ALTER TABLE products ADD COLUMN sku TEXT NOT NULL DEFAULT ''");
    }
    if (!columns.contains('min_stock')) {
      await db.execute('ALTER TABLE products ADD COLUMN min_stock INTEGER NOT NULL DEFAULT 5');
    }
  }

  static Future<void> _createNew(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS receipts(id INTEGER PRIMARY KEY AUTOINCREMENT, receipt_no TEXT NOT NULL, subtotal INTEGER NOT NULL, discount INTEGER NOT NULL, total INTEGER NOT NULL, payment TEXT NOT NULL, paid INTEGER NOT NULL, change_amount INTEGER NOT NULL, created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS receipt_items(id INTEGER PRIMARY KEY AUTOINCREMENT, receipt_id INTEGER NOT NULL, product_id INTEGER NOT NULL, name TEXT NOT NULL, qty INTEGER NOT NULL, unit_price INTEGER NOT NULL, unit_cost INTEGER NOT NULL, total INTEGER NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL, product_name TEXT NOT NULL, delta INTEGER NOT NULL, note TEXT NOT NULL, created_at TEXT NOT NULL)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_receipts_created ON receipts(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_services_status ON services(status)');
  }


  // Version 5: optional product images; keep existing rows intact.
  static Future<void> _createPhotoExtras(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(products)'))
      .map((row) => row['name'] as String).toSet();
    if (!columns.contains('photo_file')) {
      await db.execute("ALTER TABLE products ADD COLUMN photo_file TEXT NOT NULL DEFAULT ''");
    }
    // A unique index cannot be created over legacy SKU data (possible duplicates).
    // New writes are instead checked against existing rows in saveProduct().
  }

  static Future<Product?> byBarcode(String value) async {
    final code = value.trim();
    if (code.isEmpty) return null;
    final matches = await (await instance).query('products',
      where: 'sku = ? COLLATE NOCASE', whereArgs: [code], limit: 1);
    return matches.isEmpty ? null : Product.from(matches.first);
  }

  // Version 4: service intake fields, status history, partial payments.
  static Future<void> _createServiceExtras(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(services)'))
        .map((row) => row['name'] as String).toSet();
    const definitions = <String, String>{
      'imei': "TEXT NOT NULL DEFAULT ''",
      'accessories': "TEXT NOT NULL DEFAULT ''",
      'technician': "TEXT NOT NULL DEFAULT ''",
      'deposit': 'INTEGER NOT NULL DEFAULT 0',
      'priority': "TEXT NOT NULL DEFAULT 'Normal'",
      'due_at': "TEXT NOT NULL DEFAULT ''",
      'notes': "TEXT NOT NULL DEFAULT ''",
      'updated_at': "TEXT NOT NULL DEFAULT ''",
      'completed_at': "TEXT NOT NULL DEFAULT ''",
      'warranty_days': 'INTEGER NOT NULL DEFAULT 0',
      'payment_status': "TEXT NOT NULL DEFAULT 'Belum Lunas'",
      'collected_at': "TEXT NOT NULL DEFAULT ''",
    };
    for (final field in definitions.entries) {
      if (!columns.contains(field.key)) {
        await db.execute('ALTER TABLE services ADD COLUMN ${field.key} ${field.value}');
      }
    }
    await db.execute('''CREATE TABLE IF NOT EXISTS service_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      service_id INTEGER NOT NULL,
      status TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_service_events_service ON service_events(service_id)');
  }

  static Future<int> createService(Map<String, Object?> fields) async {
    final db = await instance;
    final now = DateTime.now().toIso8601String();
    return db.transaction<int>((txn) async {
      final id = await txn.insert('services', {
        ...fields, 'status': 'Antrian', 'created_at': now, 'updated_at': now,
      });
      await txn.insert('service_events', {
        'service_id': id, 'status': 'Antrian', 'note': 'Tiket service diterima', 'created_at': now,
      });
      return id;
    });
  }

  static Future<void> changeServiceStatus(int id, String status, {String note = ''}) async {
    final now = DateTime.now().toIso8601String();
    final db = await instance;
    await db.transaction((txn) async {
      final matches = await txn.query('services', where: 'id=?', whereArgs: [id], limit: 1);
      if (matches.isEmpty) throw StateError('Tiket service tidak ditemukan');
      final before = matches.first['status'] as String;
      final changes = <String, Object?>{'status': status, 'updated_at': now};
      if (status == 'Selesai' && before != 'Selesai') changes['completed_at'] = now;
      if (status == 'Diambil') changes['collected_at'] = now;
      await txn.update('services', changes, where: 'id=?', whereArgs: [id]);
      await txn.insert('service_events', {
        'service_id': id, 'status': status, 'note': note.trim(), 'created_at': now,
      });
    });
  }

  static Future<void> updateServicePayment(int id, {required int fee, required int deposit}) async {
    if (fee < 0 || deposit < 0 || deposit > fee) throw ArgumentError('Nominal pembayaran tidak valid');
    final db = await instance;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final matches = await txn.query('services', where: 'id=?', whereArgs: [id], limit: 1);
      if (matches.isEmpty) throw StateError('Service tidak ditemukan');
      await txn.update('services', {
        'fee': fee, 'deposit': deposit,
        'payment_status': fee > 0 && deposit >= fee ? 'Lunas' : 'Belum Lunas',
        'updated_at': now,
      }, where: 'id=?', whereArgs: [id]);
      await txn.insert('service_events', {
        'service_id': id, 'status': matches.first['status'],
        'note': 'Biaya: $fee • Pembayaran: $deposit', 'created_at': now,
      });
    });
  }

  static Future<List<Map<String, Object?>>> serviceEvents(int id) async {
    return (await instance).query('service_events', where: 'service_id=?',
      whereArgs: [id], orderBy: 'id DESC');
  }

  static Future<List<Product>> products() async {
    final rows = await (await instance).query('products', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Product.from).toList();
  }

  static Future<void> saveProduct({
    int? id,
    required String name,
    required String category,
    required String sku,
    String photoFile = '',
    required int stock,
    required int minStock,
    required int cost,
    required int price,
  }) async {
    final d = await instance;
    if (sku.trim().isNotEmpty) {
      final dup = await d.query('products',
        where: id == null ? 'sku = ? COLLATE NOCASE' : 'sku = ? COLLATE NOCASE AND id != ?',
        whereArgs: id == null ? [sku.trim()] : [sku.trim(), id], limit: 1);
      if (dup.isNotEmpty) throw StateError('Kode barcode/SKU sudah digunakan produk lain');
    }
    await d.transaction((txn) async {
      final data = <String, Object?>{
        'name': name,
        'category': category,
        'sku': sku.trim(),
        'photo_file': photoFile,
        'stock': stock,
        'min_stock': minStock,
        'cost': cost,
        'price': price,
      };
      if (id == null) {
        final newId = await txn.insert('products', data);
        if (stock > 0) {
          await txn.insert('stock_movements', {
            'product_id': newId, 'product_name': name, 'delta': stock,
            'note': 'Stok awal', 'created_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        final current = (await txn.query('products', where: 'id=?', whereArgs: [id])).first;
        final oldStock = current['stock'] as int;
        await txn.update('products', data, where: 'id=?', whereArgs: [id]);
        if (stock != oldStock) {
          await txn.insert('stock_movements', {
            'product_id': id, 'product_name': name, 'delta': stock - oldStock,
            'note': 'Penyesuaian manual', 'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    });
  }

  static Future<SaleResult> checkout({
    required List<CartItem> lines,
    required int discount,
    required String method,
    required int paid,
  }) async {
    if (lines.isEmpty) throw StateError('Keranjang masih kosong');
    final subtotal = lines.fold<int>(0, (s, item) => s + item.total);
    final total = subtotal - discount;
    if (discount < 0 || total < 0) throw StateError('Diskon tidak valid');
    if (paid < total) throw StateError('Pembayaran kurang');
    final now = DateTime.now();
    final iso = now.toIso8601String();
    final code = 'AG-${now.millisecondsSinceEpoch}';
    final d = await instance;
    final id = await d.transaction<int>((txn) async {
      // Check fresh stock within the same database transaction.
      for (final line in lines) {
        final rows = await txn.query('products', where: 'id=?', whereArgs: [line.product.id]);
        if (rows.isEmpty || (rows.first['stock'] as int) < line.quantity) {
          throw StateError('Stok ${line.product.name} tidak mencukupi');
        }
      }
      final receiptId = await txn.insert('receipts', {
        'receipt_no': code, 'subtotal': subtotal, 'discount': discount,
        'total': total, 'payment': method, 'paid': paid,
        'change_amount': paid - total, 'created_at': iso,
      });
      for (final line in lines) {
        final current = (await txn.query('products', where: 'id=?', whereArgs: [line.product.id])).first;
        final stock = current['stock'] as int;
        final name = current['name'] as String;
        final price = current['price'] as int;
        final cost = current['cost'] as int;
        await txn.insert('receipt_items', {
          'receipt_id': receiptId, 'product_id': line.product.id,
          'name': name, 'qty': line.quantity,
          'unit_price': price, 'unit_cost': cost, 'total': price * line.quantity,
        });
        await txn.update('products', {'stock': stock - line.quantity}, where: 'id=?', whereArgs: [line.product.id]);
        await txn.insert('stock_movements', {
          'product_id': line.product.id, 'product_name': name,
          'delta': -line.quantity, 'note': 'Penjualan $code', 'created_at': iso,
        });
      }
      return receiptId;
    });
    return SaleResult(id: id, code: code, subtotal: subtotal, discount: discount,
      total: total, paid: paid, change: paid - total, method: method,
      createdAt: iso, items: List<CartItem>.from(lines.map((e) => CartItem(e.product, e.quantity))));
  }

  static Future<Map<String, int>> summary({bool todayOnly = false}) async {
    final d = await instance;
    final filter = todayOnly ? " WHERE created_at LIKE '${DateTime.now().toIso8601String().substring(0, 10)}%'" : '';
    Future<int> aggregate(String table, String column) async {
      final rows = await d.rawQuery('SELECT COALESCE(SUM($column),0) AS n FROM $table$filter');
      return (rows.first['n'] as num).toInt();
    }
    final oldRevenue = await aggregate('sales', 'total');
    final newRevenue = await aggregate('receipts', 'total');
    final oldProfit = await aggregate('sales', 'profit');
    // Discount is applied once per receipt, to overall profit.
    final lines = await d.rawQuery('''
      SELECT COALESCE(SUM((ri.unit_price - ri.unit_cost) * ri.qty),0) AS gross
      FROM receipt_items ri JOIN receipts r ON r.id=ri.receipt_id
      ${todayOnly ? "WHERE r.created_at LIKE '${todayKey()}%'" : ''}
    ''');
    final newGross = (lines.first['gross'] as num).toInt();
    final discounts = await aggregate('receipts', 'discount');
    final fees = await aggregate('digital_transactions', 'fee');
    final expense = await aggregate('expenses', 'amount');
    final legacyCount = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM sales$filter')) ?? 0;
    final receiptCount = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM receipts$filter')) ?? 0;
    final serviceCount = Sqflite.firstIntValue(await d.rawQuery("SELECT COUNT(*) FROM services WHERE status NOT IN ('Selesai', 'Diambil')")) ?? 0;
    final totalStockAlerts = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM products WHERE stock <= min_stock')) ?? 0;
    return {
      'revenue': oldRevenue + newRevenue,
      'profit': oldProfit + newGross - discounts,
      'fees': fees, 'expenses': expense,
      'net': oldProfit + newGross - discounts + fees - expense,
      'transactions': legacyCount + receiptCount,
      'services': serviceCount,
      'low_stock': totalStockAlerts,
    };
  }

  static Future<List<Map<String, Object?>>> recentReceipts() async =>
      (await instance).query('receipts', orderBy: 'id DESC', limit: 40);

  static Future<List<Map<String, Object?>>> receiptItems(int id) async =>
      (await instance).query('receipt_items', where: 'receipt_id=?', whereArgs: [id]);
}
