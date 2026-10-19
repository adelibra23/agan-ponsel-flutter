import 'package:flutter/material.dart';
import 'barcode_scanner.dart';
import '../widgets/product_photo.dart';
import 'package:flutter/services.dart';
import '../core/database.dart';
import '../services/printer_service.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';

class PosScreen extends StatefulWidget {
  final String? initialBarcode;
  const PosScreen({super.key, this.initialBarcode});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late Future<List<Product>> loader;
  // Pending cart survives navigation between bottom tabs until checkout.
  static final Map<int, CartItem> _pending = {};
  final Map<int, CartItem> cart = _pending;
  String search = '';
  String category = 'Semua';
  @override
  void initState() {
    super.initState();
    loader = AppDatabase.products();
    if (widget.initialBarcode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) addBarcode(widget.initialBarcode!);
      });
    }
  }
  void refresh() => setState(() => loader = AppDatabase.products());
  int get subtotal => cart.values.fold(0, (a, b) => a + b.total);
  int get units => cart.values.fold(0, (a, b) => a + b.quantity);

  Future<void> addBarcode(String value) async {
    final product = await AppDatabase.byBarcode(value);
    if (!mounted) return;
    if (product == null) {
      notify(context, 'Barcode $value belum terdaftar di Produk & Stok');
      return;
    }
    addProduct(product);
    setState(() { category = 'Semua'; search = ''; });
    notify(context, '${product.name} ditambahkan ke keranjang');
  }

  Future<void> scanProduct() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const BarcodeScannerScreen()));
    if (code != null) await addBarcode(code);
  }

  void addProduct(Product product) {
    final current = cart[product.id]?.quantity ?? 0;
    if (current >= product.stock) {
      notify(context, 'Stok ${product.name} tidak mencukupi');
      return;
    }
    setState(() {
      if (current == 0) { cart[product.id] = CartItem(product); }
      else { cart[product.id]!.quantity++; }
    });
  }

  void changeQuantity(CartItem item, int difference) {
    final next = item.quantity + difference;
    if (next > item.product.stock) {
      notify(context, 'Stok produk tidak mencukupi'); return;
    }
    setState(() {
      if (next <= 0) { cart.remove(item.product.id); }
      else { item.quantity = next; }
    });
  }

  Future<void> checkout() async {
    if (cart.isEmpty) return;
    final result = await showAppSheet<SaleResult>(context, _CheckoutSheet(lines: cart.values.toList(), subtotal: subtotal));
    if (!mounted || result == null) return;
    setState(() { cart.clear(); loader = AppDatabase.products(); });
    await showAppSheet<void>(context, ReceiptDetail(result: result));
  }

  Future<void> showCart() async {
    if (cart.isEmpty) { notify(context, 'Keranjang masih kosong'); return; }
    await showAppSheet<void>(context, StatefulBuilder(builder: (ctx, update) => Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Keranjang Belanja', style: Theme.of(ctx).textTheme.titleLarge),
        const SizedBox(height: 15),
        for (final item in cart.values.toList()) ...[
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(rupiah(item.product.price), style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ])),
            IconButton(onPressed: () { changeQuantity(item, -1); update(() {}); }, icon: const Icon(Icons.remove_circle_outline)),
            Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(onPressed: () { changeQuantity(item, 1); update(() {}); }, icon: const Icon(Icons.add_circle_outline)),
          ]),
          const Divider(height: 12),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(rupiah(subtotal), style: const TextStyle(fontWeight: FontWeight.w900, color: brandBlue, fontSize: 19)),
        ]),
        const SizedBox(height: 16),
        FilledButton(onPressed: cart.isEmpty ? null : () { Navigator.pop(ctx); checkout(); },
          child: const Text('Lanjut Pembayaran')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
    future: loader, builder: (ctx, snapshot) {
      if (snapshot.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal memuat produk', subtitle: '${snapshot.error}');
      if (!snapshot.hasData) return const ScreenLoading();
      final all = snapshot.data!;
      final categories = <String>['Semua', ...all.map((e) => e.category).toSet()];
      final filtered = all.where((p) =>
        (category == 'Semua' || p.category == category) &&
        ('${p.name} ${p.sku}'.toLowerCase().contains(search.toLowerCase()))).toList();
      return Column(children: [
        Expanded(child: RefreshIndicator(onRefresh: () async { refresh(); await loader; },
          child: CustomScrollView(key: const PageStorageKey('pos-scroll'), slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const PageIntro('Kasir & Penjualan', 'Pilih produk, kelola keranjang, bayar'),
                Row(children: [
                  Expanded(child: SearchBox(hint: 'Cari produk / barcode...',
                    onChanged: (v) => setState(() => search = v))),
                  const SizedBox(width: 9),
                  IconButton.filledTonal(tooltip: 'Scan untuk tambah keranjang',
                    onPressed: scanProduct,
                    icon: const Icon(Icons.qr_code_scanner_rounded)),
                ]),
                const SizedBox(height: 12),
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: Row(children: categories.map((item) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(label: Text(item), selected: category == item,
                      onSelected: (_) => setState(() => category = item)),
                  )).toList())),
                const SizedBox(height: 7),
              ]),
            )),
            if (filtered.isEmpty) const SliverFillRemaining(child: EmptyView(
              icon: Icons.inventory_2_outlined, title: 'Belum ada produk',
              subtitle: 'Tambahkan produk melalui menu Produk & Stok.'))
            else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverLayoutBuilder(builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 600 ? 4 : 2;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns, mainAxisSpacing: 10, crossAxisSpacing: 10,
                    childAspectRatio: width >= 600 ? 1.08 : .78),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ProductTile(product: filtered[i], onAdd: () => addProduct(filtered[i])),
                    childCount: filtered.length,
                  ),
                );
              })),
          ]))),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.25)))),
          child: Row(children: [
            IconButton.filledTonal(onPressed: showCart, icon: Badge(
              label: Text('$units'), isLabelVisible: units > 0,
              child: const Icon(Icons.shopping_cart_outlined))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$units item di keranjang', style: const TextStyle(fontSize: 11)),
              Text(rupiah(subtotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ])),
            FilledButton(onPressed: cart.isEmpty ? null : checkout, child: const Text('Bayar Sekarang')),
          ]),
        ),
      ]);
    },
  );
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  const _ProductTile({required this.product, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final out = product.stock <= 0;
    return Surface(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Center(child: ProductPhoto(
          filename: product.photoFile, size: 76, radius: 18))),
        Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(rupiah(product.price), maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w900, color: brandBlue, fontSize: 13)),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: Text('Stok: ${product.stock}', style: TextStyle(
            fontSize: 11, color: out ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant))),
          SizedBox(width: 32, height: 32,
            child: IconButton.filled(onPressed: out ? null : onAdd,
              padding: EdgeInsets.zero, tooltip: 'Tambah ke keranjang',
              icon: const Icon(Icons.add, size: 20))),
        ]),
      ],
    ));
  }
}

class _CheckoutSheet extends StatefulWidget {
  final List<CartItem> lines;
  final int subtotal;
  const _CheckoutSheet({required this.lines, required this.subtotal});
  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final discount = TextEditingController(text: '0');
  final paid = TextEditingController();
  String method = 'Tunai';
  bool saving = false;

  @override
  void dispose() { discount.dispose(); paid.dispose(); super.dispose(); }

  Future<void> save() async {
    final off = nonNegative(discount.text);
    if (off == null || off > widget.subtotal) {
      notify(context, 'Diskon tidak valid'); return;
    }
    final total = widget.subtotal - off;
    final payment = method == 'Tunai' ? nonNegative(paid.text) : total;
    if (payment == null || payment < total) {
      notify(context, 'Nominal bayar kurang'); return;
    }
    setState(() => saving = true);
    try {
      final output = await AppDatabase.checkout(
        lines: widget.lines, discount: off, paid: payment, method: method);
      if (mounted) Navigator.of(context).pop(output);
    } catch (e) {
      if (mounted) { setState(() => saving = false); notify(context, '$e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final off = nonNegative(discount.text) ?? 0;
    final total = widget.subtotal - off;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Pembayaran', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 5),
      Text('${widget.lines.length} jenis produk', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 15),
      Surface(child: Column(children: [
        _BillRow('Subtotal', rupiah(widget.subtotal)),
        const SizedBox(height: 10),
        _BillRow('Diskon', rupiah(off)),
        const Divider(height: 24),
        _BillRow('Total', rupiah(total), emphasis: true),
      ])),
      const SizedBox(height: 16),
      TextField(controller: discount, keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}), decoration: inputDecoration('Diskon (Rp)', icon: Icons.local_offer_outlined)),
      const SizedBox(height: 16),
      const Text('Metode pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: ['Tunai', 'Transfer', 'E-Wallet'].map((item) =>
        ChoiceChip(label: Text(item), selected: method == item,
          onSelected: (_) => setState(() => method = item))).toList()),
      const SizedBox(height: 12),
      if (method == 'Tunai') ...[
        TextField(controller: paid, keyboardType: TextInputType.number,
          decoration: inputDecoration('Nominal dibayar (Rp)', icon: Icons.payments_outlined)),
        const SizedBox(height: 12),
      ],
      FilledButton.icon(onPressed: saving ? null : save,
        icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) :
          const Icon(Icons.check_circle_outline),
        label: const Text('Selesaikan Transaksi')),
    ]);
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool emphasis;
  const _BillRow(this.label, this.amount, {this.emphasis = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: TextStyle(fontWeight: emphasis ? FontWeight.w900 : FontWeight.w500)),
    Text(amount, style: TextStyle(fontWeight: FontWeight.w900,
      fontSize: emphasis ? 20 : 14, color: emphasis ? brandBlue : null)),
  ]);
}

String receiptText(SaleResult r) {
  final buffer = StringBuffer()
    ..writeln('          AGAN PONSEL')
    ..writeln('HP • AKSESORIS • SERVICE • DIGITAL')
    ..writeln('--------------------------------')
    ..writeln('No: ${r.code}')
    ..writeln('Tanggal: ${dateLabel(r.createdAt)} ${timeLabel(r.createdAt)}')
    ..writeln('--------------------------------');
  for (final item in r.items) {
    buffer.writeln(item.product.name);
    buffer.writeln('${item.quantity} x ${rupiah(item.product.price)} = ${rupiah(item.total)}');
  }
  buffer
    ..writeln('--------------------------------')
    ..writeln('Subtotal: ${rupiah(r.subtotal)}')
    ..writeln('Diskon: ${rupiah(r.discount)}')
    ..writeln('TOTAL: ${rupiah(r.total)}')
    ..writeln('Metode: ${r.method}')
    ..writeln('Bayar: ${rupiah(r.paid)}')
    ..writeln('Kembali: ${rupiah(r.change)}')
    ..writeln('--------------------------------')
    ..writeln('Terima kasih sudah berbelanja!');
  return buffer.toString();
}

class ReceiptDetail extends StatelessWidget {
  final SaleResult result;
  const ReceiptDetail({super.key, required this.result});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Center(child: CircleAvatar(radius: 27, backgroundColor: Color(0xFFDCF8EA),
        child: Icon(Icons.check_circle, size: 32, color: Color(0xFF08A96B)))),
      const SizedBox(height: 12),
      Text('Transaksi Berhasil', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      Text(result.code, textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      const SizedBox(height: 16),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final line in result.items) ...[
          Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          _BillRow('${line.quantity} × ${rupiah(line.product.price)}', rupiah(line.total)),
          const SizedBox(height: 9),
        ],
        const Divider(height: 18),
        _BillRow('Diskon', rupiah(result.discount)),
        const SizedBox(height: 6),
        _BillRow('Total', rupiah(result.total), emphasis: true),
        _BillRow('Kembali', rupiah(result.change)),
      ])),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: () async {
        await Clipboard.setData(ClipboardData(text: receiptText(result)));
        if (context.mounted) notify(context, 'Struk berhasil disalin');
      }, icon: const Icon(Icons.copy_rounded), label: const Text('Salin Struk')),
      const SizedBox(height: 7),
      OutlinedButton.icon(onPressed: () async {
        try {
          await AganPrinter.printSale(result);
          if (context.mounted) notify(context, 'Struk berhasil dikirim ke printer');
        } catch (e) {
          if (context.mounted) notify(context, 'Gagal mencetak: $e. Atur printer di menu Pengaturan.');
        }
      }, icon: const Icon(Icons.print_rounded), label: const Text('Cetak via Printer Bluetooth')),
      const SizedBox(height: 5),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Selesai')),
    ],
  );
}
