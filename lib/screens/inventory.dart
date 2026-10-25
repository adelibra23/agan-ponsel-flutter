import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/product_photos.dart';
import '../widgets/product_photo.dart';
import 'barcode_scanner.dart';
import 'store_finance_plus.dart';
import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';

class InventoryScreen extends StatefulWidget {
  final bool lowOnly;
  final String? initialBarcode;
  const InventoryScreen({super.key, this.lowOnly = false, this.initialBarcode});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<Product>> loader;
  String search = '';
  String category = 'Semua';
  @override
  void initState() {
    super.initState();
    loader = AppDatabase.products();
    final initial = widget.initialBarcode;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) edit(null, barcode: initial);
      });
    }
  }
  void reload() => setState(() => loader = AppDatabase.products());

  Future<void> edit(Product? product, {String? barcode}) async {
    final saved = await showAppSheet<bool>(context,
      _ProductForm(product: product, initialBarcode: barcode));
    if (saved == true) reload();
  }

  Future<void> scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const BarcodeScannerScreen()));
    if (!mounted || code == null) return;
    final exists = await AppDatabase.byBarcode(code);
    if (!mounted) return;
    if (exists != null) {
      setState(() { category = 'Semua'; search = code; });
      await edit(exists);
    } else {
      await edit(null, barcode: code);
    }
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
        child: ListView(key: const PageStorageKey('inventory-scroll'), padding: const EdgeInsets.fromLTRB(16, 20, 16, 85), children: [
          PageIntro(widget.lowOnly ? 'Stok Menipis' : 'Produk & Stok',
            'Kelola stok, kategori, modal dan harga jual'),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const InventoryInsightScreen())),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Insight Stok, Margin & Ekspor CSV')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SearchBox(hint: 'Cari produk / barcode...',
              onChanged: (v) => setState(() => search = v))),
            const SizedBox(width: 9),
            IconButton.filledTonal(tooltip: 'Scan barcode', onPressed: scan,
              icon: const Icon(Icons.qr_code_scanner_rounded)),
          ]),
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
                ProductPhoto(filename: item.photoFile, size: 54, radius: 16),
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
  final String? initialBarcode;
  const _ProductForm({required this.product, this.initialBarcode});
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final name = TextEditingController(text: widget.product?.name ?? '');
  late final sku = TextEditingController(text: widget.product?.sku ?? widget.initialBarcode ?? '');
  late String photoFile = widget.product?.photoFile ?? '';
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

  Future<void> scanCode() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const BarcodeScannerScreen()));
    if (mounted && code != null) setState(() => sku.text = code);
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final value = await ProductPhotos.pick(source);
      if (mounted && value != null) setState(() => photoFile = value);
    } catch (e) { if (mounted) notify(context, 'Tidak dapat mengambil foto: $e'); }
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
        category: category, sku: sku.text.trim(), photoFile: photoFile,
        stock: s, minStock: m, cost: c, price: p);
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
      Row(children: [
        ProductPhoto(filename: photoFile, size: 78, radius: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton.icon(onPressed: () => pickPhoto(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined), label: const Text('Foto kamera')),
          OutlinedButton.icon(onPressed: () => pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeri')),
        ])),
      ]),
      const SizedBox(height: 15),
      TextField(controller: name, decoration: inputDecoration('Nama produk', icon: Icons.shopping_bag_outlined)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: sku,
          decoration: inputDecoration('Barcode / SKU', icon: Icons.qr_code_2_rounded))),
        const SizedBox(width: 8),
        IconButton.filledTonal(tooltip: 'Scan barcode dari kamera', onPressed: scanCode,
          icon: const Icon(Icons.qr_code_scanner_rounded)),
        IconButton.filledTonal(tooltip: 'Buat SKU otomatis',
          onPressed: () => setState(() => sku.text =
            'AGP-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}'),
          icon: const Icon(Icons.auto_awesome_rounded)),
      ]),
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
        Expanded(child: TextField(controller: cost, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number,
          decoration: inputDecoration('Harga modal'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: price, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number,
          decoration: inputDecoration('Harga jual'))),
      ]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE9F6EF), borderRadius: BorderRadius.circular(14)),
        child: Text('Estimasi laba kotor / unit: ${rupiah((nonNegative(price.text) ?? 0) - (nonNegative(cost.text) ?? 0))}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF147C54)))),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF0F8BDB), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('Tip: scan kode pada kemasan, atau buat SKU otomatis. Foto tersimpan di perangkat dan ikut dalam backup.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11))),
      ]),
      const SizedBox(height: 19),
      FilledButton(onPressed: busy ? null : save,
        child: Text(busy ? 'Menyimpan...' : 'Simpan Produk')),
    ],
  );
}
