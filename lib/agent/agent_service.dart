import 'package:shared_preferences/shared_preferences.dart';
import '../core/database.dart';
import '../core/format.dart';
import '../services/receivables_service.dart';
import 'agent_intents.dart';

class AgentResult {
  final String message;
  final AgentIntent? proposal;
  final String? destination;
  const AgentResult(this.message, {this.proposal, this.destination});
}

class AgentService {
  AgentService._();
  static const helpText = 'Saya AGANA, asisten pencatatan AGAN PONSEL. '
      'Saya membaca data toko di HP ini dan mengenali perintah bahasa Indonesia tertentu.\n\n'
      'Contoh:\n'
      '• cek tagihan Budi\n'
      '• siapa yang jatuh tempo\n'
      '• cek stok charger\n'
      '• stok menipis\n'
      '• cek service Andi\n'
      '• laporan hari ini\n'
      '• tambah pelanggan Budi 081234567890\n'
      '• catat pengeluaran 25000 untuk isolasi\n'
      '• tambah catatan pesan LCD Redmi\n'
      '• catat piutang Budi; 150000; 2026-11-01; pulsa\n\n'
      'Setiap pencatatan harus kamu konfirmasi. Untuk transaksi kompleks, '
      'saya akan membuka halaman yang sesuai. Saya tidak terhubung ke rekening, '
      'tagihan provider. Jika API AI diaktifkan, AGANA bisa menjawab pertanyaan umum lewat penyedia pilihanmu.';

  static Future<AgentResult> ask(String text) async {
    final intent = AgentParser.parse(text);
    if (intent.kind == 'debt' && RegExp(r'^(listrik|pln|pdam|bpjs|indihome)$',
      caseSensitive: false).hasMatch(intent.argument)) {
      return const AgentResult('Saya hanya dapat memeriksa piutang yang dicatat di AGAN PONSEL. '
        'Tagihan PLN, BPJS, dan penyedia layanan lain perlu dicek melalui layanan resminya.');
    }
    if (intent.needsApproval) {
      if (intent.argument.length > 90 || intent.description.length > 220 ||
          intent.argument.isEmpty && intent.kind != 'new_note' && intent.kind != 'new_expense' ||
          intent.description.isEmpty && intent.kind != 'new_customer') {
        return const AgentResult('Nama atau keterangan terlalu panjang atau kosong. Periksa perintahmu.');
      }
      if (intent.kind == 'new_debt' && (intent.dueDate!.year < 2020 || intent.dueDate!.year > 2100)) {
        return const AgentResult('Tanggal jatuh tempo harus berada antara tahun 2020 dan 2100.');
      }
      return AgentResult(_preview(intent), proposal: intent);
    }
    switch (intent.kind) {
      case 'help': return const AgentResult(helpText);
      case 'invalid_amount': return const AgentResult('Nominal tidak valid. Contoh: catat pengeluaran 25000 untuk isolasi');
      case 'invalid_customer': return const AgentResult('Nomor HP harus 8–15 digit. Contoh: tambah pelanggan Budi 081234567890');
      case 'invalid_debt': return const AgentResult('Format: catat piutang Nama; 150000; 2026-11-01; Keterangan');
      case 'pay_debt': return const AgentResult('Pembayaran dan perubahan jatuh tempo harus dicatat lewat detail piutang agar nominal dan riwayatnya diperiksa. Silakan buka daftar piutang.', destination: 'debt');
      case 'open_debt': return const AgentResult('Buka Piutang untuk mengisi formulir lengkap dan mengatur tanggal jatuh tempo.', destination: 'debt');
      case 'open_inventory': return const AgentResult('Buka Produk & Stok untuk menambah produk, foto, atau memindai barcode.', destination: 'inventory');
      case 'open_service': return const AgentResult('Buka Service HP dan pilih Service Baru untuk mengisi tiket secara lengkap.', destination: 'service');
      case 'open_customers': return const AgentResult('Buka Pelanggan untuk memilih dari kontak HP atau memasukkan data manual.', destination: 'customers');
      case 'open_expenses': return const AgentResult('Buka Pengeluaran untuk pencatatan manual dengan formulir.', destination: 'expenses');
      case 'open_notes': return const AgentResult('Buka Catatan & Tugas untuk mengelola daftar pekerjaan toko.', destination: 'notes');
      case 'open_sales': return const AgentResult('Buka Riwayat Penjualan untuk melihat transaksi dan struk.', destination: 'sales');
      case 'due_debt':
      case 'debt':
        return _debts(intent.kind == 'due_debt' ? null : intent.argument);
      case 'low_stock':
      case 'stock':
        return _stock(intent.kind == 'low_stock' ? null : intent.argument, intent.kind == 'low_stock');
      case 'services': return _services(intent.argument);
      case 'summary': return _summary(intent.argument == 'today');
      case 'cash':
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('cash_balance_visible') != true) {
          return const AgentResult('Saldo sedang disembunyikan lewat ikon mata. Buka Buku Kas lalu tekan ikon mata untuk menampilkan saldo.', destination: 'cash');
        }
        return AgentResult('Saldo kas tercatat: ${rupiah(await AppDatabase.cashBalance())}. Angka ini bukan saldo rekening bank.', destination: 'cash');
      default:
        return const AgentResult('Saya belum memahami perintah tersebut. Coba pilih contoh di bawah atau ketik "bantuan". Perintah bebas di luar pola yang didukung tidak akan saya jalankan.');
    }
  }

  static String _preview(AgentIntent value) {
    switch (value.kind) {
      case 'new_customer': return 'Periksa data pelanggan sebelum menyimpan:\nNama: ${value.argument}\nNomor: ${value.phone}';
      case 'new_expense': return 'Periksa pengeluaran sebelum menyimpan:\nNominal: ${rupiah(value.amount)}\nKeterangan: ${value.description}';
      case 'new_debt': return 'Periksa piutang sebelum menyimpan:\nPelanggan: ${value.argument}\nNominal: ${rupiah(value.amount)}\nJatuh tempo: ${value.dueDate!.toIso8601String().substring(0, 10)}\nKeterangan: ${value.description}';
      case 'new_note': return 'Periksa tugas sebelum menyimpan:\n${value.description}';
      default: return 'Tindakan tidak dikenal.';
    }
  }

  static Future<AgentResult> _debts(String? q) async {
    final list = await ReceivablesService.all();
    final needle = (q ?? '').toLowerCase().trim();
    final rows = list.where((x) => !x.isPaid && (needle.isEmpty ||
      '${x.customer} ${x.phone} ${x.description}'.toLowerCase().contains(needle)) &&
      (q != null || x.overdue || x.dueSoon)).take(8).toList();
    if (rows.isEmpty) return AgentResult(q == null
      ? 'Tidak ada piutang terlambat atau jatuh tempo dalam tiga hari dari data yang tercatat.'
      : 'Tidak ditemukan piutang aktif${needle.isNotEmpty ? ' untuk "$q"' : ''}.', destination: 'debt');
    final total = rows.fold<int>(0, (sum, r) => sum + r.remaining);
    final body = rows.map((r) => '• ${r.customer}: ${rupiah(r.remaining)} — ${r.dueText}').join('\n');
    return AgentResult('Piutang tercatat (${rows.length} data ditampilkan):\n$body\n\nTotal yang ditampilkan: ${rupiah(total)}. Lihat Piutang untuk daftar lengkap.', destination: 'debt');
  }

  static Future<AgentResult> _stock(String? q, bool lowOnly) async {
    final products = await AppDatabase.products();
    final needle = (q ?? '').toLowerCase().trim();
    final result = products.where((p) => (!lowOnly || p.stock <= p.minStock) &&
      (needle.isEmpty || '${p.name} ${p.sku} ${p.category}'.toLowerCase().contains(needle))).take(10).toList();
    if (result.isEmpty) return AgentResult(lowOnly
      ? 'Tidak ada produk di bawah atau sama dengan batas minimum stok.'
      : 'Produk tidak ditemukan. Coba nama atau SKU yang lebih singkat.', destination: 'inventory');
    return AgentResult('Hasil stok (${result.length} produk ditampilkan):\n${result.map((p) => '• ${p.name}: ${p.stock} unit (min. ${p.minStock}) • ${rupiah(p.price)}').join('\n')}', destination: 'inventory');
  }

  static Future<AgentResult> _services(String q) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('services', orderBy: 'id DESC', limit: 300);
    final needle = q.trim().toLowerCase();
    final found = rows.where((r) => needle.isEmpty ||
      '${r['customer']} ${r['device']} ${r['phone']} ${r['status']}'.toLowerCase().contains(needle)).take(8).toList();
    if (found.isEmpty) return const AgentResult('Tiket service tidak ditemukan pada data lokal.', destination: 'service');
    return AgentResult('Status service (${found.length} tiket ditampilkan):\n${found.map((r) => '• ${r['customer']} — ${r['device']}: ${r['status']}').join('\n')}', destination: 'service');
  }

  static Future<AgentResult> _summary(bool today) async {
    final data = await AppDatabase.summary(todayOnly: today);
    return AgentResult('Ringkasan ${today ? 'hari ini' : 'seluruh periode'}:\n'
      '• Omzet: ${rupiah(data['revenue'] ?? 0)}\n'
      '• Estimasi laba kotor: ${rupiah(data['profit'] ?? 0)}\n'
      '• Pengeluaran: ${rupiah(data['expenses'] ?? 0)}\n'
      '• Transaksi: ${data['transactions'] ?? 0}\n'
      '• Service aktif: ${data['services'] ?? 0}\n'
      '• Stok menipis: ${data['low_stock'] ?? 0}\n\n'
      'Ringkasan mengikuti transaksi yang telah dicatat; tidak menggantikan audit akuntansi.',
      destination: 'reports');
  }

  /// The UI calls this ONLY after tapping a user-facing approval button.
  static Future<String> confirm(AgentIntent intent) async {
    if (!intent.needsApproval) throw StateError('Perintah bukan transaksi yang dapat disimpan');
    final db = await AppDatabase.instance;
    final timestamp = DateTime.now().toIso8601String();
    if (intent.kind == 'new_debt') {
      if (intent.amount <= 0 || intent.amount > 1000000000 ||
          intent.argument.trim().isEmpty || intent.description.trim().isEmpty) {
        throw const FormatException('Data piutang tidak valid');
      }
      return db.transaction<String>((txn) async {
        final id = await txn.insert('receivables', {
          'customer_name': intent.argument.trim(), 'phone': '',
          'description': intent.description.trim(), 'amount': intent.amount,
          'due_date': intent.dueDate!.toIso8601String().substring(0, 10),
          'notes': '', 'created_at': timestamp,
        });
        await txn.insert('agent_activity', {'action': 'new_debt', 'created_at': timestamp});
        return 'Piutang berhasil dicatat, tiket #$id. Buka Piutang untuk mengelolanya.';
      });
    }
    // Commit the record and its activity entry together.
    return db.transaction<String>((txn) async {
      String done;
      switch (intent.kind) {
        case 'new_customer':
          final exists = await txn.query('customers', where: 'phone=?', whereArgs: [intent.phone], limit: 1);
          if (exists.isNotEmpty) throw StateError('Nomor pelanggan ini sudah tercatat. Tidak ada data baru ditambahkan.');
          await txn.insert('customers', {'name': intent.argument, 'phone': intent.phone, 'note': 'Ditambahkan melalui AGANA'});
          done = 'Pelanggan ${intent.argument} berhasil ditambahkan.';
          break;
        case 'new_expense':
          await txn.insert('expenses', {'description': intent.description, 'amount': intent.amount, 'created_at': timestamp});
          done = 'Pengeluaran ${rupiah(intent.amount)} berhasil dicatat.';
          break;
        case 'new_note':
          if (intent.description.length > 240) throw const FormatException('Tugas terlalu panjang');
          await txn.insert('store_notes', {'text': intent.description, 'done': 0, 'created_at': timestamp});
          done = 'Catatan berhasil ditambahkan.';
          break;
        default: throw StateError('Perintah tidak didukung');
      }
      await txn.insert('agent_activity', {'action': intent.kind, 'created_at': timestamp});
      return done;
    });
  }

  static Future<List<Map<String, Object?>>> activity() async {
    final db = await AppDatabase.instance;
    return db.query('agent_activity', orderBy: 'id DESC', limit: 30);
  }
}
