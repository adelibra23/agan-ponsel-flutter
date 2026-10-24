import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/database.dart';
import '../core/format.dart';
import '../services/restock_service.dart';
import '../widgets/kit.dart';

class RestockCenterScreen extends StatefulWidget {
  const RestockCenterScreen({super.key});
  @override
  State<RestockCenterScreen> createState() => _RestockCenterScreenState();
}

class _RestockCenterScreenState extends State<RestockCenterScreen> {
  int revision = 0;
  void reload() => setState(() => revision++);

  Future<void> open(Widget screen) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Restock & Supplier'),
        actions: [IconButton(tooltip: 'Muat ulang', onPressed: reload,
          icon: const Icon(Icons.refresh_rounded))],
        bottom: const TabBar(isScrollable: true, tabs: [
          Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Stok Menipis'),
          Tab(icon: Icon(Icons.inventory_rounded), text: 'Rencana Pembelian'),
          Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Supplier'),
        ]),
      ),
      body: TabBarView(children: [
        _LowStockTab(key: ValueKey('low-$revision'),
          onCreate: () => open(const RestockEditorScreen())),
        _OrdersTab(key: ValueKey('orders-$revision'),
          onCreate: () => open(const RestockEditorScreen()),
          onOpen: open),
        _SuppliersTab(key: ValueKey('suppliers-$revision'),
          onCreate: () => open(const SupplierEditorScreen()),
          onOpen: open),
      ]),
    ),
  );
}

class _LowStockTab extends StatelessWidget {
  final VoidCallback onCreate;
  const _LowStockTab({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
    future: RestockService.lowStockProducts(),
    builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('Gagal membaca stok: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data!;
      final estimated = rows.fold<int>(0, (total, item) => total +
        RestockService.suggestedQty(item.stock, item.minStock) * item.cost);
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 36), children: [
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kebutuhan pengadaan', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${rows.length} produk perlu diperhatikan',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text('Estimasi modal: ${rupiah(estimated)}',
            style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onCreate,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Buat Rencana Restock')),
        ])),
        const SizedBox(height: 16),
        if (rows.isEmpty) const EmptyView(
          icon: Icons.inventory_2_outlined,
          title: 'Stok aman',
          subtitle: 'Tidak ada produk pada atau di bawah batas stok minimum.'),
        for (final item in rows) ...[
          Surface(child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Stok ${item.stock} • Minimum ${item.minStock} • '
              'Saran beli ${RestockService.suggestedQty(item.stock, item.minStock)}'),
            trailing: Text(rupiah(item.cost),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 9),
        ],
      ]);
    },
  );
}

class _OrdersTab extends StatelessWidget {
  final VoidCallback onCreate;
  final Future<void> Function(Widget) onOpen;
  const _OrdersTab({super.key, required this.onCreate, required this.onOpen});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RestockOrder>>(
    future: RestockService.orders(),
    builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('Gagal memuat rencana: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final orders = snap.data!;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add),
          label: const Text('Buat Rencana Pembelian')),
        const SizedBox(height: 16),
        if (orders.isEmpty) const EmptyView(icon: Icons.shopping_bag_outlined,
          title: 'Belum ada rencana',
          subtitle: 'Buat rencana pengadaan barang dari stok menipis.'),
        for (final order in orders) ...[
          Surface(child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => onOpen(RestockDetailScreen(order: order)),
            leading: Icon(order.status == 'received' ? Icons.check_circle_rounded
              : order.status == 'cancelled' ? Icons.cancel_outlined
                : Icons.pending_actions_rounded),
            title: Text('RESTOCK #${order.id}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${order.supplierName.isEmpty ? 'Tanpa supplier' : order.supplierName}\n'
              '${order.status == 'received' ? 'Diterima' : order.status == 'cancelled' ? 'Dibatalkan' : 'Rencana'} '
              '• ${order.createdAt.substring(0, 10)}'),
            isThreeLine: true,
            trailing: Text(rupiah(order.estimatedTotal),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 9),
        ],
      ]);
    },
  );
}

class _SuppliersTab extends StatelessWidget {
  final VoidCallback onCreate;
  final Future<void> Function(Widget) onOpen;
  const _SuppliersTab({super.key, required this.onCreate, required this.onOpen});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SupplierEntry>>(
    future: RestockService.suppliers(),
    builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('Gagal memuat supplier: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Tambah Supplier')),
        const SizedBox(height: 16),
        if (snap.data!.isEmpty) const EmptyView(icon: Icons.local_shipping_outlined,
          title: 'Belum ada supplier',
          subtitle: 'Simpan kontak pemasok untuk memudahkan pemesanan.'),
        for (final supplier in snap.data!) ...[
          Surface(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.store_rounded),
            title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(supplier.phone.isEmpty ? supplier.address : supplier.phone),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => onOpen(SupplierEditorScreen(supplier: supplier)),
          )),
          const SizedBox(height: 9),
        ],
      ]);
    },
  );
}

class SupplierEditorScreen extends StatefulWidget {
  final SupplierEntry? supplier;
  const SupplierEditorScreen({super.key, this.supplier});
  @override
  State<SupplierEditorScreen> createState() => _SupplierEditorScreenState();
}

class _SupplierEditorScreenState extends State<SupplierEditorScreen> {
  late final name = TextEditingController(text: widget.supplier?.name ?? '');
  late final phone = TextEditingController(text: widget.supplier?.phone ?? '');
  late final address = TextEditingController(text: widget.supplier?.address ?? '');
  late final note = TextEditingController(text: widget.supplier?.note ?? '');
  bool saving = false;

  @override
  void dispose() {
    name.dispose(); phone.dispose(); address.dispose(); note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await RestockService.saveSupplier(id: widget.supplier?.id,
        name: name.text, phone: phone.text, address: address.text, note: note.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.supplier == null ? 'Tambah Supplier' : 'Edit Supplier')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      TextField(controller: name, maxLength: 100,
        decoration: const InputDecoration(labelText: 'Nama pemasok *')),
      const SizedBox(height: 10),
      TextField(controller: phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Nomor WhatsApp / Telepon')),
      const SizedBox(height: 10),
      TextField(controller: address, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Alamat pemasok')),
      const SizedBox(height: 10),
      TextField(controller: note, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Catatan pemasok')),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: saving ? null : save,
        icon: const Icon(Icons.save_rounded),
        label: Text(saving ? 'Menyimpan...' : 'Simpan Supplier')),
    ]),
  );
}

class RestockEditorScreen extends StatefulWidget {
  const RestockEditorScreen({super.key});
  @override
  State<RestockEditorScreen> createState() => _RestockEditorScreenState();
}

class _RestockEditorScreenState extends State<RestockEditorScreen> {
  bool loading = true;
  bool busy = false;
  bool lowOnly = true;
  List<Product> products = [];
  List<SupplierEntry> suppliers = [];
  final quantities = <int, int>{};
  int? supplierId;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await AppDatabase.products();
      final suppliersList = await RestockService.suppliers();
      for (final product in rows) {
        final qty = RestockService.suggestedQty(product.stock, product.minStock);
        if (qty > 0) quantities[product.id] = qty;
      }
      if (mounted) setState(() {
        products = rows;
        suppliers = suppliersList;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() { note.dispose(); super.dispose(); }

  List<RestockDraftLine> get selected => [
    for (final product in products)
      if ((quantities[product.id] ?? 0) > 0)
        RestockDraftLine(product, quantities[product.id]!),
  ];

  void changeQty(Product product, int delta) {
    setState(() {
      final qty = (quantities[product.id] ?? 0) + delta;
      quantities[product.id] = qty.clamp(0, 9999).toInt();
    });
  }

  Future<void> save() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih setidaknya satu barang.')));
      return;
    }
    setState(() => busy = true);
    try {
      await RestockService.createOrder(supplierId: supplierId,
        note: note.text, lines: selected);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = products.where((p) => !lowOnly || p.stock <= p.minStock).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Rencana Restock')),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 95), children: [
          DropdownButtonFormField<int?>(
            value: supplierId,
            decoration: const InputDecoration(labelText: 'Pemasok / Supplier'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Belum memilih supplier')),
              for (final supplier in suppliers)
                DropdownMenuItem<int?>(value: supplier.id, child: Text(supplier.name)),
            ],
            onChanged: (value) => setState(() => supplierId = value),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: lowOnly,
            onChanged: (v) => setState(() => lowOnly = v),
            title: const Text('Tampilkan stok menipis saja'),
            subtitle: const Text('Jumlah disarankan hingga 2× stok minimum')),
          const SizedBox(height: 8),
          for (final product in visible) ...[
            Surface(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Stok ${product.stock} • Min ${product.minStock}\n'
                  'Modal ${rupiah(product.cost)} / unit',
                  style: Theme.of(context).textTheme.bodySmall),
              ])),
              IconButton(onPressed: () => changeQty(product, -1),
                icon: const Icon(Icons.remove_circle_outline_rounded)),
              Text('${quantities[product.id] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => changeQty(product, 1),
                icon: const Icon(Icons.add_circle_outline_rounded)),
            ])),
            const SizedBox(height: 9),
          ],
          TextField(controller: note, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Catatan pemesanan')),
          const SizedBox(height: 12),
          Text('Produk dipilih: ${selected.length} • Estimasi: '
            '${rupiah(RestockService.estimateCost(selected))}',
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Membuat rencana TIDAK mengubah stok, kas, atau pengeluaran.',
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: busy ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(busy ? 'Menyimpan...' : 'Simpan Rencana Restock')),
        ]),
    );
  }
}

class RestockDetailScreen extends StatefulWidget {
  final RestockOrder order;
  const RestockDetailScreen({super.key, required this.order});
  @override
  State<RestockDetailScreen> createState() => _RestockDetailScreenState();
}

class _RestockDetailScreenState extends State<RestockDetailScreen> {
  bool busy = false;

  Future<String> orderMessage() async {
    final lines = await RestockService.orderLines(widget.order.id);
    final buffer = StringBuffer('AGAN PONSEL • RENCANA RESTOCK #${widget.order.id}\n');
    if (widget.order.supplierName.isNotEmpty) {
      buffer.writeln('Supplier: ${widget.order.supplierName}');
    }
    for (var i = 0; i < lines.length; i++) {
      final item = lines[i];
      buffer.writeln('${i + 1}. ${item.productName} • ${item.qty} × '
        '${rupiah(item.unitCost)} = ${rupiah(item.total)}');
    }
    buffer.writeln('Estimasi: ${rupiah(widget.order.estimatedTotal)}');
    if (widget.order.note.isNotEmpty) buffer.writeln('Catatan: ${widget.order.note}');
    buffer.writeln('Mohon konfirmasi stok dan harga sebelum dikirim.');
    return buffer.toString();
  }

  Future<void> copyList() async {
    final text = await orderMessage();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daftar restock tersalin.')));
  }

  String? whatsappPhone(String raw) {
    final number = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.startsWith('08')) return '62${number.substring(1)}';
    if (number.startsWith('628')) return number;
    if (number.startsWith('00628')) return number.substring(2);
    return null;
  }

  Future<void> whatsappSupplier() async {
    final suppliers = await RestockService.suppliers();
    SupplierEntry? contact;
    for (final supplier in suppliers) {
      if (supplier.id == widget.order.supplierId) contact = supplier;
    }
    final phone = whatsappPhone(contact?.phone ?? '');
    if (phone == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp supplier tidak valid.')));
      return;
    }
    final uri = Uri.https('wa.me', '/$phone', {'text': await orderMessage()});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka WhatsApp.')));
    }
  }

  Future<void> complete({required bool receive}) async {
    final approved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(receive ? 'Konfirmasi Barang Diterima?' : 'Batalkan Rencana?'),
      content: Text(receive
        ? 'Stok produk akan bertambah sesuai jumlah barang pada rencana. '
          'Setiap penambahan dicatat dalam Riwayat Stok. '
          'Kas dan Pengeluaran TIDAK berubah otomatis.'
        : 'Rencana dibatalkan tanpa mengubah stok.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Kembali')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text(receive ? 'Barang Sudah Diterima' : 'Ya, Batalkan')),
      ],
    ));
    if (approved != true) return;
    setState(() => busy = true);
    try {
      if (receive) {
        await RestockService.receiveOrder(widget.order.id);
      } else {
        await RestockService.cancelOrder(widget.order.id);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Restock #${widget.order.id}')),
    body: FutureBuilder<List<RestockOrderLine>>(
      future: RestockService.orderLines(widget.order.id),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Gagal: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(padding: const EdgeInsets.all(16), children: [
          Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.order.supplierName.isEmpty ? 'Tanpa supplier'
              : widget.order.supplierName,
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            Text('Status: ${widget.order.status} • ${widget.order.createdAt.substring(0, 10)}'),
            const SizedBox(height: 7),
            Text('Estimasi modal: ${rupiah(widget.order.estimatedTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ])),
          const SizedBox(height: 16),
          for (final item in snap.data!) ...[
            Surface(child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productName),
              subtitle: Text('${item.qty} × ${rupiah(item.unitCost)}'),
              trailing: Text(rupiah(item.total)),
            )),
            const SizedBox(height: 9),
          ],
          if (widget.order.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Catatan: ${widget.order.note}'),
          ],
          const SizedBox(height: 15),
          OutlinedButton.icon(onPressed: copyList,
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Salin Daftar Belanja')),
          if (widget.order.supplierId != null && widget.order.status == 'draft') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: whatsappSupplier,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Kirim Pesan ke WhatsApp Supplier')),
          ],
          if (widget.order.status == 'draft') ...[
            const SizedBox(height: 15),
            FilledButton.icon(onPressed: busy ? null : () => complete(receive: true),
              icon: const Icon(Icons.inventory_2_rounded),
              label: const Text('Konfirmasi Barang Diterima')),
            TextButton(onPressed: busy ? null : () => complete(receive: false),
              child: const Text('Batalkan Rencana')),
          ],
        ]);
      },
    ),
  );
}
