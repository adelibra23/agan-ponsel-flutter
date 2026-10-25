import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/database.dart';
import '../core/format.dart';
import '../services/store_plus_service.dart';
import '../widgets/kit.dart';

String _csv(List<Object?> cells) => cells.map((value) =>
  '"${(value ?? '').toString().replaceAll('"', '""')}"').join(',');

Future<void> _saveCsv(BuildContext context, String name, List<List<Object?>> data) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF${data.map(_csv).join('\r\n')}\r\n'));
    final result = await FilePicker.saveFile(dialogTitle: 'Ekspor CSV AGAN PONSEL',
      fileName: name, bytes: bytes);
    if (context.mounted) notify(context,
      result == null ? 'Penyimpanan dibatalkan' : 'CSV disimpan di lokasi pilihan');
  } catch (e) { if (context.mounted) notify(context, 'Gagal ekspor: $e'); }
}

class CashInsightsScreen extends StatefulWidget {
  const CashInsightsScreen({super.key});
  @override
  State<CashInsightsScreen> createState() => _CashInsightsScreenState();
}

class _CashInsightsScreenState extends State<CashInsightsScreen> {
  late Future<List<Map<String, Object?>>> rows;
  late Future<Map<String, int>> stats;
  String filter = 'Semua';
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() {
    rows = StorePlusService.cashMovements();
    stats = StorePlusService.cashStats();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Analisis Buku Kas')),
    body: FutureBuilder<List<Map<String, Object?>>>(future: rows, builder: (ctx, snapshot) {
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      if (!snapshot.hasData) return const ScreenLoading();
      final all = snapshot.data!;
      final shown = all.where((row) {
        final delta = row['delta'] as int;
        return filter == 'Semua' || (filter == 'Masuk' ? delta > 0 : delta < 0);
      }).toList();
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        const PageIntro('Audit kas manual',
          'Rincian penyesuaian manual. Bukan saldo rekening atau hasil sinkron bank.'),
        FutureBuilder<Map<String, int>>(future: stats, builder: (c, data) {
          if (!data.hasData) return const ScreenLoading();
          final d = data.data!;
          return Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Setoran manual: ${rupiah(d['incoming']!)}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Pengambilan manual: ${rupiah(d['outgoing']!)}'),
            const SizedBox(height: 8),
            Text('Selisih penyesuaian: ${rupiah(d['incoming']! - d['outgoing']!)}'),
            const SizedBox(height: 8),
            Text('${d['count']} penyesuaian tercatat'),
          ]));
        }),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'Semua', label: Text('Semua')),
          ButtonSegment(value: 'Masuk', label: Text('Masuk')),
          ButtonSegment(value: 'Keluar', label: Text('Keluar')),
        ], selected: {filter}, onSelectionChanged: (s) => setState(() => filter = s.first)),
        const SizedBox(height: 10),
        OutlinedButton.icon(icon: const Icon(Icons.file_download_outlined),
          label: const Text('Ekspor Buku Kas CSV'),
          onPressed: () => _saveCsv(context, 'agan-ponsel-buku-kas-${todayKey()}.csv', [
            ['ID', 'Tanggal', 'Jenis', 'Nominal', 'Catatan'],
            for (final r in shown) [r['id'], r['created_at'],
              (r['delta'] as int) >= 0 ? 'Masuk' : 'Keluar', r['delta'], r['note']],
          ])),
        for (final r in shown) Padding(padding: const EdgeInsets.only(top: 9),
          child: Surface(child: ListTile(contentPadding: EdgeInsets.zero,
            leading: Icon((r['delta'] as int) >= 0 ? Icons.call_received : Icons.call_made),
            title: Text('${r['note']}'),
            subtitle: Text(dateLabel('${r['created_at']}')),
            trailing: Text(rupiah(r['delta'] as int),
              style: const TextStyle(fontWeight: FontWeight.w800))))),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.all(28),
          child: Text('Belum ada penyesuaian kas.')),
      ]);
    }),
  );
}

class FinanceReportScreen extends StatefulWidget {
  const FinanceReportScreen({super.key});
  @override
  State<FinanceReportScreen> createState() => _FinanceReportScreenState();
}

class _FinanceReportScreenState extends State<FinanceReportScreen> {
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  late Future<Map<String, int>> report;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => report = StorePlusService.report(from, to));

  Future<void> range() async {
    final result = await showDateRangePicker(context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: from, end: to));
    if (result == null) return;
    from = result.start; to = result.end; refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Laporan Periode'), actions: [
      IconButton(tooltip: 'Pilih periode', onPressed: range,
        icon: const Icon(Icons.date_range_outlined))]),
    body: FutureBuilder<Map<String, int>>(future: report, builder: (ctx, snap) {
      if (snap.hasError) return Center(child: Text('Laporan gagal dimuat: ${snap.error}'));
      if (!snap.hasData) return const ScreenLoading();
      final v = snap.data!;
      final items = <(String, int, IconData)>[
        ('Omzet Kasir', v['revenue']!, Icons.point_of_sale_outlined),
        ('Laba Kotor Barang', v['profit']!, Icons.trending_up_outlined),
        ('Admin Digital Selesai', v['fees']!, Icons.phone_android_outlined),
        ('Pengeluaran', v['expenses']!, Icons.payments_outlined),
        ('Estimasi Hasil', v['net']!, Icons.account_balance_wallet_outlined),
      ];
      return ListView(padding: const EdgeInsets.all(16), children: [
        const PageIntro('Ringkasan Periode', 'Pilih tanggal awal dan akhir laporan.'),
        OutlinedButton.icon(onPressed: range, icon: const Icon(Icons.calendar_today),
          label: Text('${dateLabel(from.toIso8601String())} – ${dateLabel(to.toIso8601String())}')),
        const SizedBox(height: 14),
        for (final row in items) Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Surface(child: ListTile(contentPadding: EdgeInsets.zero,
            leading: Icon(row.$3), title: Text(row.$1),
            trailing: Text(rupiah(row.$2), style: const TextStyle(fontWeight: FontWeight.w800))))),
        OutlinedButton.icon(icon: const Icon(Icons.copy), label: const Text('Salin ringkasan'),
          onPressed: () async {
            final text = 'AGAN PONSEL • LAPORAN\n${dateLabel(from.toIso8601String())} – '
              '${dateLabel(to.toIso8601String())}\n'
              '${items.map((e) => '${e.$1}: ${rupiah(e.$2)}').join('\n')}';
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) notify(context, 'Ringkasan tersalin');
          }),
        OutlinedButton.icon(icon: const Icon(Icons.file_download_outlined),
          label: const Text('Ekspor ringkasan CSV'), onPressed: () => _saveCsv(context,
            'agan-ponsel-laporan-${todayKey()}.csv', [
            ['Periode awal', from.toIso8601String().substring(0, 10)],
            ['Periode akhir', to.toIso8601String().substring(0, 10)],
            ['Keterangan', 'Nilai Rupiah'],
            for (final e in items) [e.$1, e.$2],
          ])),
        const SizedBox(height: 12),
        Text('Perkiraan usaha, bukan laporan laba bersih akuntansi. Belum termasuk '
          'pajak, biaya service yang belum diterima, piutang, atau rekonsiliasi bank.',
          style: Theme.of(context).textTheme.bodySmall),
      ]);
    }),
  );
}

class InventoryInsightScreen extends StatefulWidget {
  const InventoryInsightScreen({super.key});
  @override
  State<InventoryInsightScreen> createState() => _InventoryInsightScreenState();
}

class _InventoryInsightScreenState extends State<InventoryInsightScreen> {
  late Future<Map<String, int>> stats;
  late Future<List<Product>> products;
  @override
  void initState() {
    super.initState();
    stats = StorePlusService.inventoryStats();
    products = AppDatabase.products();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Insight Produk & Stok')),
    body: FutureBuilder<Map<String, int>>(future: stats, builder: (ctx, sn) {
      if (sn.hasError) return Center(child: Text('${sn.error}'));
      if (!sn.hasData) return const ScreenLoading();
      final s = sn.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        const PageIntro('Nilai persediaan',
          'Perkiraan berdasarkan harga modal/jual yang disimpan pada produk.'),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estimasi modal stok: ${rupiah(s['capital']!)}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('Potensi omzet seluruh stok: ${rupiah(s['selling']!)}'),
          const SizedBox(height: 10),
          Text('Potensi margin kotor: ${rupiah(s['selling']! - s['capital']!)}'),
          const SizedBox(height: 10),
          Text('${s['items']} jenis • ${s['units']} unit • ${s['low']} stok menipis • ${s['empty']} habis'),
        ])),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async {
          try {
            final all = await products;
            if (!context.mounted) return;
            await _saveCsv(context, 'agan-ponsel-nilai-stok-${todayKey()}.csv', [
              ['ID', 'Nama', 'SKU', 'Kategori', 'Stok', 'Stok Minimal',
               'Harga Modal', 'Harga Jual', 'Modal Stok', 'Potensi Omzet'],
              for (final p in all) [p.id,p.name,p.sku,p.category,p.stock,
                p.minStock,p.cost,p.price,p.stock*p.cost,p.stock*p.price],
            ]);
          } catch (e) { if (context.mounted) notify(context, '$e'); }
        }, icon: const Icon(Icons.file_download), label: const Text('Ekspor Persediaan CSV')),
        const SizedBox(height: 12),
        const SectionTitle('Produk perlu perhatian'),
        FutureBuilder<List<Product>>(future: products, builder: (c, productsSnap) {
          if (!productsSnap.hasData) return const ScreenLoading();
          final low = productsSnap.data!.where((p) => p.stock <= p.minStock).toList();
          if (low.isEmpty) return const Surface(child: Text('Semua stok di atas batas minimum.'));
          return Column(children: [for (final p in low.take(30)) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Surface(child: ListTile(contentPadding: EdgeInsets.zero,
              title: Text(p.name), subtitle: Text('Min. ${p.minStock} • SKU ${p.sku}'),
              trailing: Text('Stok ${p.stock}'))))]);
        }),
      ]);
    }),
  );
}
