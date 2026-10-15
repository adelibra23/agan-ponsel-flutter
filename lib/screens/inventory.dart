import 'package:flutter/material.dart';
import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';

class InventoryScreen extends StatefulWidget {
  final bool lowOnly;
  const InventoryScreen({super.key, this.lowOnly = false});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<Product>> loader;
  String search = '';
  String category = 'Semua';
  @override
  void initState() { super.initState(); loader = AppDatabase.products(); }
  void reload() => setState(() => loader = AppDatabase.products());

  Future<void> edit(Product? product) async {
    final saved = await showAppSheet<bool>(context, _ProductForm(product: product));
    if (saved == true) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: FutureBuilder<List<Product>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal memuat produk', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final all = snap.data!;
      final categories = ['Semua', ...all.map((e) => e.category).toSet()];
      final rows = all.where((p) =>
        (!widget.lowOnly || p.stock <= p.minStock) &&
        (category == 'Semua' || p.category == category) &&
        '${p.name} ${p.sku}'.toLowerCase().contains(search.toLowerCase())).toList();
      return RefreshIndicator(onRefresh: () async { reload(); await loader; },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 85), children: [
          PageIntro(widget.lowOnly ? 'Stok Menipis' : 'Produk & Stok',
            'Kelola stok, kategori, modal dan harga jual'),
          SearchBox(hint: 'Cari produk / kode barang...', onChanged: (v) => setState(() => search = v)),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
            children: categories.map((e) => Padding(padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(label: Text(e), selected: category == e,
                onSelected: (_) => setState(() => category = e)))).toList())),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 75), child: EmptyView(
              icon: Icons.inventory_2_outlined, title: 'Belum ada produk',
              subtitle: 'Tekan tombol + untuk menambah produk.')),
          for (final item in rows) ...[
            Surface(child: InkWell(
              onTap: () => edit(item),
              borderRadius: BorderRadius.circular(17),
              child: Row(children: [
                Container(width: 54, height: 54,
                  decoration: BoxDecoration(color: brandBlue.withOpacity(.10),
                    borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.inventory_2_rounded, color: brandBlue)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(item.category + (item.sku.isEmpty ? '' : ' • ${item.sku}'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                      fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 5),
                  Text(rupiah(item.price), style: const TextStyle(fontWeight: FontWeight.w800, color: brandBlue)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Pill('Stok ${item.stock}', color: item.stock <= item.minStock ? Colors.orange : Colors.green),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ]),
              ]),
            )),
            const SizedBox(height: 10),
          ],
        ]));
    }),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(null), backgroundColor: brandBlue, foregroundColor: Colors.white,
      label: const Text('Tambah Produk'), icon: const Icon(Icons.add_rounded)),
  );
}

class _ProductForm extends StatefulWidget {
  final Product? product;
  const _ProductForm({required this.product});
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final name = TextEditingController(text: widget.product?.name ?? '');
  late final sku = TextEditingController(text: widget.product?.sku ?? '');
  late final stock = TextEditingController(text: '${widget.product?.stock ?? 0}');
  late final minStock = TextEditingController(text: '${widget.product?.minStock ?? 5}');
  late final cost = TextEditingController(text: '${widget.product?.cost ?? 0}');
  late final price = TextEditingController(text: '${widget.product?.price ?? 0}');
  late String category = widget.product?.category ?? 'Aksesoris';
  bool busy = false;

  @override
  void dispose() {
    name.dispose(); sku.dispose(); stock.dispose(); minStock.dispose(); cost.dispose(); price.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final s = nonNegative(stock.text);
    final m = nonNegative(minStock.text);
    final c = nonNegative(cost.text);
    final p = nonNegative(price.text);
    if (name.text.trim().isEmpty || s == null || m == null || c == null || p == null) {
      notify(context, 'Lengkapi nama produk dan angka yang valid'); return;
    }
    setState(() => busy = true);
    try {
      await AppDatabase.saveProduct(id: widget.product?.id, name: name.text.trim(),
        category: category, sku: sku.text.trim(), stock: s, minStock: m, cost: c, price: p);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => busy = false); notify(context, 'Gagal menyimpan: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.product == null ? 'Tambah Produk Baru' : 'Edit Produk & Stok',
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      TextField(controller: name, decoration: inputDecoration('Nama produk', icon: Icons.shopping_bag_outlined)),
      const SizedBox(height: 12),
      TextField(controller: sku, decoration: inputDecoration('Kode / SKU (opsional)', icon: Icons.qr_code_2_rounded)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: category,
        decoration: inputDecoration('Kategori'),
        items: ['Aksesoris', 'HP', 'Pulsa', 'Sparepart', 'Elektronik', 'Lainnya',
          if (!['Aksesoris', 'HP', 'Pulsa', 'Sparepart', 'Elektronik', 'Lainnya'].contains(category)) category]
          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) { if (v != null) setState(() => category = v); }),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number,
          decoration: inputDecoration('Stok saat ini'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: minStock, keyboardType: TextInputType.number,
          decoration: inputDecoration('Minimal stok'))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number,
          decoration: inputDecoration('Harga modal'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: price, keyboardType: TextInputType.number,
          decoration: inputDecoration('Harga jual'))),
      ]),
      const SizedBox(height: 19),
      FilledButton(onPressed: busy ? null : save,
        child: Text(busy ? 'Menyimpan...' : 'Simpan Produk')),
    ],
  );
}
