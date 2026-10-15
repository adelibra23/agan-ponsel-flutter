import 'package:flutter/material.dart';
import 'contact_picker.dart';
import 'inventory.dart';
import 'cash_screen.dart';
import 'store_notes.dart';
import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';
import 'pos.dart';
import 'settings/settings_pages.dart';
import 'security/pin_screens.dart';

class MoreScreen extends StatelessWidget {
  final ValueChanged<Widget> open;
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  const MoreScreen({super.key, required this.open, required this.dark, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 25), children: [
      const PageIntro('Manajemen Toko', 'Fitur tambahan untuk operasional AGAN PONSEL'),
      _MenuItem(icon: Icons.people_alt_rounded, color: const Color(0xFF7D50D6),
        title: 'Pelanggan & Kontak', subtitle: 'Input manual atau pilih dari kontak HP', onTap: () => open(const CustomersScreen())),
      _MenuItem(icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF1F68D7),
        title: 'Saldo & Kas Toko', subtitle: 'Saldo kas, setoran dan penarikan manual', onTap: () => open(const CashScreen())),
      _MenuItem(icon: Icons.task_alt_rounded, color: const Color(0xFF4B78A8),
        title: 'Catatan & Tugas', subtitle: 'Checklist kegiatan toko offline', onTap: () => open(const StoreNotesScreen())),
      _MenuItem(icon: Icons.notification_important_outlined, color: const Color(0xFFDD8517),
        title: 'Stok Menipis', subtitle: 'Pantau produk di bawah batas minimum',
        onTap: () => open(const InventoryScreen(lowOnly: true))),
      _MenuItem(icon: Icons.sim_card_rounded, color: const Color(0xFF0D87CF),
        title: 'Pulsa & Transaksi Digital', subtitle: 'Catat paket data, top up, admin', onTap: () => open(const DigitalScreen())),
      _MenuItem(icon: Icons.payments_rounded, color: const Color(0xFFE76655),
        title: 'Pengeluaran', subtitle: 'Biaya operasional toko', onTap: () => open(const ExpensesScreen())),
      _MenuItem(icon: Icons.insights_rounded, color: const Color(0xFF289779),
        title: 'Laporan Keuangan', subtitle: 'Omzet, laba kotor, pengeluaran', onTap: () => open(const ReportsScreen())),
      _MenuItem(icon: Icons.receipt_long_rounded, color: brandBlue,
        title: 'Riwayat Penjualan', subtitle: 'Struk dan transaksi kasir', onTap: () => open(const SalesHistoryScreen())),
      _MenuItem(icon: Icons.swap_vert_circle_outlined, color: const Color(0xFFAD721E),
        title: 'Riwayat Stok', subtitle: 'Penambahan dan pengurangan stok', onTap: () => open(const StockHistoryScreen())),
      _MenuItem(icon: Icons.lock_person_rounded, color: const Color(0xFF16A387),
        title: 'Keamanan & Biometrik', subtitle: 'PIN, wajah atau sidik jari Android',
        onTap: () => open(const PinSettingsScreen())),
      _MenuItem(icon: Icons.account_circle_outlined, color: const Color(0xFF2783DC),
        title: 'Akun & Profil', subtitle: 'Identitas pengelola dan toko offline',
        onTap: () => open(const AccountSettingsScreen())),
      _MenuItem(icon: Icons.backup_rounded, color: const Color(0xFF8054CB),
        title: 'Backup & Restore', subtitle: 'Simpan data SQLite, pulihkan saat ganti HP',
        onTap: () => open(const BackupRestoreScreen())),
      _MenuItem(icon: Icons.print_rounded, color: const Color(0xFF2196B8),
        title: 'Printer Bluetooth', subtitle: 'Hubungkan thermal printer 58/80 mm',
        onTap: () => open(const BluetoothPrinterScreen())),
      _MenuItem(icon: Icons.settings_suggest_rounded, color: const Color(0xFF697E94),
        title: 'Pengaturan', subtitle: 'Tampilan, keamanan, printer dan logo toko',
        onTap: () => open(SettingsScreen(dark: dark, onThemeChanged: onThemeChanged))),
      const SizedBox(height: 18),
      Surface(child: Row(children: [
        const Icon(Icons.offline_bolt_rounded, color: Color(0xFF09B681)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Offline-first', style: TextStyle(fontWeight: FontWeight.w900)),
          Text('Tidak memerlukan server komputer',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
      ])),
    ],
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Surface(padding: EdgeInsets.zero, child: ListTile(
      onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(width: 45, height: 45, decoration: BoxDecoration(
        color: color.withOpacity(.11), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right_rounded),
    )),
  );
}

class StorePage extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const StorePage({super.key, required this.title, required this.child, this.action});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      actions: action == null ? null : [action!]),
    body: SafeArea(child: child),
  );
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<Map<String, Object?>>> loader;
  String query = '';
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => loader = AppDatabase.instance.then((d) => d.query('customers', orderBy: 'id DESC')));

  Future<void> importContact() async {
    final result = await Navigator.of(context).push<ContactChoice>(
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()));
    if (!mounted || result == null) return;
    final cleaned = result.number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final db = await AppDatabase.instance;
    final existing = await db.query('customers', where: 'phone=?', whereArgs: [cleaned], limit: 1);
    if (!mounted) return;
    if (existing.isNotEmpty) { notify(context, 'Nomor sudah tercatat di pelanggan'); return; }
    await db.insert('customers', {'name': result.name, 'phone': cleaned,
      'note': 'Dipilih dari kontak HP'});
    if (mounted) { refresh(); notify(context, 'Pelanggan ditambahkan'); }
  }

  Future<void> add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final result = await showAppSheet<bool>(context, Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tambah Pelanggan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async {
          final choice = await Navigator.of(context).push<ContactChoice>(
            MaterialPageRoute(builder: (_) => const ContactPickerScreen()));
          if (choice != null) { name.text = choice.name;
            phone.text = choice.number.replaceAll(RegExp(r'[^0-9+]'), ''); }
        }, icon: const Icon(Icons.contacts_rounded), label: const Text('Pilih dari Kontak HP')),
        const SizedBox(height: 13),
        TextField(controller: name, decoration: inputDecoration('Nama pelanggan')),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: inputDecoration('Nomor HP')),
        const SizedBox(height: 10),
        TextField(controller: note, maxLines: 2, decoration: inputDecoration('Catatan pelanggan')),
        const SizedBox(height: 18),
        FilledButton(onPressed: () {
          if (name.text.trim().isEmpty) { notify(context, 'Nama pelanggan wajib diisi'); return; }
          Navigator.pop(context, true);
        }, child: const Text('Simpan Pelanggan')),
      ],
    ));
    if (result == true) {
      await (await AppDatabase.instance).insert('customers', {
        'name': name.text.trim(), 'phone': phone.text.trim(), 'note': note.text.trim(),
      });
      if (mounted) refresh();
    }
    // The modal route has completed before controllers are released.
    name.dispose(); phone.dispose(); note.dispose();
  }

  @override
  Widget build(BuildContext context) => StorePage(title: 'Pelanggan',
    action: Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(tooltip: 'Ambil dari kontak HP', onPressed: importContact,
        icon: const Icon(Icons.contact_phone_rounded)),
      IconButton(tooltip: 'Tambah manual', onPressed: add,
        icon: const Icon(Icons.person_add_alt_rounded)),
    ]),
    child: FutureBuilder<List<Map<String, Object?>>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Tidak bisa membaca pelanggan', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final data = snap.data!.where((row) => '${row['name']} ${row['phone']}'.toLowerCase().contains(query.toLowerCase())).toList();
      return ListView(padding: const EdgeInsets.all(16), children: [
        SearchBox(hint: 'Cari nama atau nomor HP...', onChanged: (s) => setState(() => query = s)),
        const SizedBox(height: 16),
        if (data.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 90),
          child: EmptyView(icon: Icons.people_outline, title: 'Belum ada pelanggan', subtitle: 'Tambah kontak dari ikon di kanan atas.')),
        for (final row in data) ...[
          Surface(child: ListTile(contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: brandBlue.withOpacity(.10),
              child: const Icon(Icons.person_rounded, color: brandBlue)),
            title: Text('${row['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${row['phone']}\n${row['note']}', maxLines: 2,
              overflow: TextOverflow.ellipsis),
            isThreeLine: '${row['note']}'.isNotEmpty)),
          const SizedBox(height: 9),
        ],
      ]);
    }),
  );
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late Future<List<Map<String, Object?>>> loader;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => loader = AppDatabase.instance.then((d) => d.query('expenses', orderBy: 'id DESC')));

  Future<void> add() async {
    final desc = TextEditingController();
    final amount = TextEditingController();
    final result = await showAppSheet<bool>(context, Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Catat Pengeluaran', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: desc, decoration: inputDecoration('Keterangan pengeluaran')),
        const SizedBox(height: 10),
        TextField(controller: amount, keyboardType: TextInputType.number,
          decoration: inputDecoration('Nominal pengeluaran (Rp)')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () {
          if (desc.text.trim().isEmpty || nonNegative(amount.text) == null || nonNegative(amount.text) == 0) {
            notify(context, 'Isi keterangan dan nominal yang benar'); return;
          }
          Navigator.pop(context, true);
        }, child: const Text('Simpan Pengeluaran')),
      ]));
    if (result == true) {
      await (await AppDatabase.instance).insert('expenses', {
        'description': desc.text.trim(), 'amount': nonNegative(amount.text)!,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) refresh();
    }
    desc.dispose(); amount.dispose();
  }

  @override
  Widget build(BuildContext context) => StorePage(title: 'Pengeluaran',
    action: IconButton(onPressed: add, icon: const Icon(Icons.add_circle_outline_rounded)),
    child: FutureBuilder<List<Map<String, Object?>>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal memuat pengeluaran', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final data = snap.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Surface(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total pengeluaran', style: TextStyle(fontWeight: FontWeight.w700)),
          Text(rupiah(data.fold<int>(0, (a, b) => a + (b['amount'] as int))),
            style: const TextStyle(color: Color(0xFFE4545A), fontWeight: FontWeight.w900)),
        ])),
        const SizedBox(height: 14),
        if (data.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 90),
          child: EmptyView(icon: Icons.payments_outlined, title: 'Belum ada pengeluaran', subtitle: 'Tekan tombol + di kanan atas.')),
        for (final row in data) ...[
          Surface(child: ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE4545A)),
            title: Text('${row['description']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(dateLabel(row['created_at'] as String)),
            trailing: Text(rupiah(row['amount'] as int), style: const TextStyle(fontWeight: FontWeight.w800)))),
          const SizedBox(height: 9),
        ],
      ]);
    }),
  );
}

class DigitalScreen extends StatefulWidget {
  const DigitalScreen({super.key});
  @override
  State<DigitalScreen> createState() => _DigitalScreenState();
}

class _DigitalScreenState extends State<DigitalScreen> {
  late Future<List<Map<String, Object?>>> loader;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => loader = AppDatabase.instance.then((d) => d.query('digital_transactions', orderBy: 'id DESC')));
  Future<void> add() async {
    final destination = TextEditingController();
    final nominal = TextEditingController();
    final fee = TextEditingController(text: '5000');
    String operator = 'Telkomsel';
    final result = await showAppSheet<(String, String, int, int)>(context,
      StatefulBuilder(builder: (ctx, update) => Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Transaksi Digital Offline', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Pencatatan saja, tidak mengirim pulsa / uang otomatis.',
            style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: operator,
            decoration: inputDecoration('Jenis layanan'),
            items: ['Telkomsel', 'XL', 'Indosat', 'Tri', 'Smartfren', 'Axis',
              'Transfer Bank', 'Tarik Tunai', 'E-Wallet', 'Token PLN', 'Lainnya']
              .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) { if (v != null) update(() => operator = v); }),
          const SizedBox(height: 10),
          TextField(controller: destination, decoration: inputDecoration('Nomor tujuan / pelanggan')),
          const SizedBox(height: 10),
          TextField(controller: nominal, keyboardType: TextInputType.number,
            decoration: inputDecoration('Nominal transaksi (Rp)')),
          const SizedBox(height: 10),
          TextField(controller: fee, keyboardType: TextInputType.number,
            decoration: inputDecoration('Biaya admin (Rp)')),
          const SizedBox(height: 18),
          FilledButton(onPressed: () {
            final n = nonNegative(nominal.text);
            final f = nonNegative(fee.text);
            if (destination.text.trim().isEmpty || n == null || f == null) {
              notify(ctx, 'Lengkapi tujuan, nominal dan biaya admin'); return;
            }
            Navigator.pop(ctx, (operator, destination.text.trim(), n, f));
          }, child: const Text('Catat Transaksi')),
        ],
      )));
    if (result != null) {
      await (await AppDatabase.instance).insert('digital_transactions', {
        'operator': result.$1, 'destination': result.$2,
        'nominal': result.$3, 'fee': result.$4,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) refresh();
    }
    destination.dispose(); nominal.dispose(); fee.dispose();
  }
  @override
  Widget build(BuildContext context) => StorePage(title: 'Pulsa & Digital',
    action: IconButton(onPressed: add, icon: const Icon(Icons.add_rounded)),
    child: FutureBuilder<List<Map<String, Object?>>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal membaca transaksi', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final data = snap.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Surface(child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: brandBlue),
          const SizedBox(width: 10),
          Expanded(child: Text('Mode pencatatan offline. Transfer dan top up sungguhan perlu koneksi penyedia layanan.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ])),
        const SizedBox(height: 16),
        if (data.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 90),
          child: EmptyView(icon: Icons.sim_card_outlined, title: 'Belum ada transaksi digital',
            subtitle: 'Tekan + untuk mencatat pembayaran admin.')),
        for (final row in data) ...[
          Surface(child: ListTile(contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.phone_android_rounded)),
            title: Text('${row['operator']} • ${rupiah(row['nominal'] as int)}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${row['destination']}\n${dateLabel(row['created_at'] as String)}'),
            isThreeLine: true,
            trailing: Text('+${rupiah(row['fee'] as int)}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF09A875))))),
          const SizedBox(height: 9),
        ],
      ]);
    }),
  );
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool today = true;
  @override
  Widget build(BuildContext context) => StorePage(title: 'Laporan Keuangan',
    child: FutureBuilder<Map<String, int>>(
      key: ValueKey(today), future: AppDatabase.summary(todayOnly: today), builder: (ctx, snap) {
        if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal membaca laporan', subtitle: '${snap.error}');
        if (!snap.hasData) return const ScreenLoading();
        final v = snap.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<bool>(segments: const [
            ButtonSegment(value: true, label: Text('Hari ini'), icon: Icon(Icons.today)),
            ButtonSegment(value: false, label: Text('Semua waktu'), icon: Icon(Icons.calendar_month)),
          ], selected: {today}, onSelectionChanged: (values) => setState(() => today = values.first)),
          const SizedBox(height: 18),
          const SectionTitle('Ikhtisar toko'),
          _ReportCard(title: 'Omzet Penjualan', value: rupiah(v['revenue']!), color: brandBlue, icon: Icons.trending_up),
          _ReportCard(title: 'Laba Kotor Penjualan', value: rupiah(v['profit']!), color: const Color(0xFF00AA7C), icon: Icons.auto_graph),
          _ReportCard(title: 'Pendapatan Admin Digital', value: rupiah(v['fees']!), color: const Color(0xFF8056D5), icon: Icons.phone_android),
          _ReportCard(title: 'Pengeluaran', value: rupiah(v['expenses']!), color: const Color(0xFFE56950), icon: Icons.payments_outlined),
          const SizedBox(height: 10),
          Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Estimasi hasil setelah pengeluaran', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Text(rupiah(v['net']!), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: brandBlue)),
            const SizedBox(height: 10),
            Text('${v['transactions']} transaksi kasir tercatat', style: const TextStyle(fontSize: 12)),
          ])),
          const SizedBox(height: 17),
          Text('Catatan: Laba service belum dihitung sebagai pendapatan diterima. Laporan ini belum termasuk pajak dan piutang.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]);
      }));
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const _ReportCard({required this.title, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10),
    child: Surface(child: Row(children: [
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(
        color: color.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: color)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ])),
    ])));
}

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late Future<List<Map<String, Object?>>> loader;
  @override
  void initState() { super.initState(); loader = AppDatabase.recentReceipts(); }

  Future<void> showReceipt(Map<String, Object?> row) async {
    final id = row['id'] as int;
    final lines = await AppDatabase.receiptItems(id);
    if (!mounted) return;
    final items = lines.map((v) => CartItem(Product(
      id: v['product_id'] as int, name: v['name'] as String, category: '', sku: '', stock: 0,
      minStock: 0, cost: v['unit_cost'] as int, price: v['unit_price'] as int,
    ), v['qty'] as int)).toList();
    final receipt = SaleResult(id: id, code: row['receipt_no'] as String,
      subtotal: row['subtotal'] as int, discount: row['discount'] as int,
      total: row['total'] as int, paid: row['paid'] as int,
      change: row['change_amount'] as int, method: row['payment'] as String,
      createdAt: row['created_at'] as String, items: items);
    await showAppSheet<void>(context, ReceiptDetail(result: receipt));
  }

  @override
  Widget build(BuildContext context) => StorePage(title: 'Riwayat Penjualan',
    child: FutureBuilder<List<Map<String, Object?>>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Tidak bisa memuat riwayat', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final items = snap.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('40 transaksi kasir terbaru • ketuk untuk melihat struk',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 14),
        if (items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 90),
          child: EmptyView(icon: Icons.receipt_long_outlined, title: 'Belum ada transaksi',
            subtitle: 'Transaksi keranjang baru akan terlihat di sini.')),
        for (final row in items) ...[
          Surface(child: ListTile(onTap: () => showReceipt(row), contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Color(0xFFE8F6EE),
              child: Icon(Icons.receipt_long_rounded, color: Color(0xFF04A36C))),
            title: Text('${row['receipt_no']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${dateLabel(row['created_at'] as String)} • ${row['payment']}'),
            trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rupiah(row['total'] as int), style: const TextStyle(fontWeight: FontWeight.w900)),
              const Icon(Icons.chevron_right_rounded, size: 19),
            ]))),
          const SizedBox(height: 9),
        ],
      ]);
    }),
  );
}

class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => StorePage(title: 'Pergerakan Stok',
    child: FutureBuilder<List<Map<String, Object?>>>(
      future: AppDatabase.instance.then((d) => d.query('stock_movements', orderBy: 'id DESC', limit: 100)),
      builder: (ctx, snap) {
        if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal memuat stok', subtitle: '${snap.error}');
        if (!snap.hasData) return const ScreenLoading();
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (snap.data!.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 90),
            child: EmptyView(icon: Icons.swap_vert, title: 'Belum ada perubahan stok',
              subtitle: 'Riwayat tercatat saat stok diubah atau produk terjual.')),
          for (final row in snap.data!) ...[
            Surface(child: ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon((row['delta'] as int) < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: (row['delta'] as int) < 0 ? Colors.red : Colors.green),
              title: Text('${row['product_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${row['note']} • ${dateLabel(row['created_at'] as String)}'),
              trailing: Text('${(row['delta'] as int) > 0 ? '+' : ''}${row['delta']}',
                style: const TextStyle(fontWeight: FontWeight.w900)))),
            const SizedBox(height: 9),
          ],
        ]);
      }));
}

class SettingsScreen extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  const SettingsScreen({super.key, required this.dark, required this.onThemeChanged});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool currentDark = widget.dark;
  void go(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  void changeTheme(bool value) {
    setState(() => currentDark = value);
    widget.onThemeChanged(value);
  }

  @override
  Widget build(BuildContext context) => StorePage(title: 'Pengaturan',
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 17, 16, 35), children: [
      Container(padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(colors: [Color(0xFF0735B1), Color(0xFF0E9AEF)])),
        child: const Row(children: [
          CircleAvatar(radius: 27, backgroundColor: Colors.white,
            child: Text('AG', style: TextStyle(color: brandBlue,
              fontSize: 19, fontWeight: FontWeight.w900))),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AGAN PONSEL', style: TextStyle(fontWeight: FontWeight.w900,
              fontSize: 21, color: Colors.white)),
            SizedBox(height: 4),
            Text('Flutter Offline • v0.6.0 Build 9',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ])),
      const SizedBox(height: 22),
      const SectionTitle('Keamanan aplikasi'),
      _MenuItem(icon: Icons.shield_rounded, color: const Color(0xFF13A283),
        title: 'PIN & Biometrik', subtitle: 'Aktifkan PIN dan autentikasi perangkat',
        onTap: () => go(const PinSettingsScreen())),
      const SizedBox(height: 14),
      const SectionTitle('Akun & identitas toko'),
      SettingsCard(icon: Icons.manage_accounts_rounded, color: brandBlue,
        title: 'Pengaturan Akun', subtitle: 'Profil lokal, nomor kontak, alamat dan footer struk',
        onTap: () => go(const AccountSettingsScreen())),
      SettingsCard(icon: Icons.image_rounded, color: const Color(0xFF4874D5),
        title: 'Logo & Branding', subtitle: 'Ganti logo toko yang tampil di header',
        onTap: () => go(const StoreBrandSettingsScreen())),
      SettingsCard(icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF0D9B7F),
        title: 'Saldo & Buku Kas', subtitle: 'Kas manual, nominal disembunyikan',
        onTap: () => go(const CashScreen())),
      const SizedBox(height: 12),
      const SectionTitle('Penyimpanan & perangkat'),
      SettingsCard(icon: Icons.backup_outlined, color: const Color(0xFF8751D1),
        title: 'Backup & Restore', subtitle: 'Simpan dan pulihkan data SQLite',
        onTap: () => go(const BackupRestoreScreen())),
      SettingsCard(icon: Icons.print_rounded, color: const Color(0xFF189ABA),
        title: 'Printer Bluetooth', subtitle: 'Printer thermal ESC/POS 58 mm atau 80 mm',
        onTap: () => go(const BluetoothPrinterScreen())),
      SettingsCard(icon: Icons.storage_rounded, color: const Color(0xFF28A578),
        title: 'Database SQLite', subtitle: 'Periksa tabel, versi, dan integritas data lokal',
        onTap: () => go(const DatabaseInfoScreen())),
      const SizedBox(height: 12),
      const SectionTitle('Tampilan & informasi'),
      Surface(child: SwitchListTile(contentPadding: EdgeInsets.zero,
        secondary: Icon(currentDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: brandBlue),
        title: const Text('Mode Gelap', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('Tema mengikuti pilihan yang tersimpan'),
        value: currentDark, onChanged: changeTheme)),
      const SizedBox(height: 10),
      SettingsCard(icon: Icons.info_outline_rounded, color: const Color(0xFF63748D),
        title: 'Tentang Aplikasi', subtitle: 'Versi, fitur, privasi dan informasi penggunaan',
        onTap: () => go(const AboutAganScreen())),
      const SizedBox(height: 10),
      Text('Data tersimpan di HP. Backup terlebih dahulu sebelum uninstall atau hapus data aplikasi.',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]));
}
