import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cash_screen.dart';
import 'store_notes.dart';
import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';
import 'services.dart';
import 'inventory.dart';
import 'pos.dart';
import 'others.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int> navigate;
  final ValueChanged<Widget> open;
  const DashboardScreen({super.key, required this.navigate, required this.open});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, int>> stats;
  @override
  void initState() { super.initState(); stats = AppDatabase.summary(todayOnly: true); }
  void reload() => setState(() => stats = AppDatabase.summary(todayOnly: true));

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, int>>(
    future: stats,
    builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Database belum bisa dibuka',
        subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final data = snap.data!;
      return RefreshIndicator(onRefresh: () async { reload(); await stats; }, child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 26), children: [
        _Welcome(onTap: reload),
        const SizedBox(height: 13),
        BalanceCard(onOpen: () => widget.open(const CashScreen())),
        const SizedBox(height: 12),
        _DailyGoal(revenue: data['revenue']!),
        const SizedBox(height: 18),
        const SectionTitle('Ringkasan hari ini', subtitle: 'Pantau performa toko secara langsung'),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: 1.48,
          children: [
            StatTile(title: 'Penjualan', value: rupiah(data['revenue']!), color: const Color(0xFF00A968), icon: Icons.shopping_bag_outlined),
            StatTile(title: 'Laba kotor', value: rupiah(data['profit']!), color: brandBlue, icon: Icons.auto_graph_rounded),
            StatTile(title: 'Transaksi', value: '${data['transactions']}', color: const Color(0xFFEF9400), icon: Icons.receipt_long_rounded),
            StatTile(title: 'Service aktif', value: '${data['services']}', color: const Color(0xFFF04A75), icon: Icons.handyman_rounded),
          ],
        ),
        const SizedBox(height: 23),
        const SectionTitle('Menu utama', subtitle: 'Semua aktivitas toko dalam satu tempat'),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 4, childAspectRatio: .68,
          children: [
            QuickIcon(icon: Icons.point_of_sale_rounded, color: const Color(0xFF00AB73), label: 'Kasir', action: () => widget.navigate(1)),
            QuickIcon(icon: Icons.inventory_2_rounded, color: brandBlue, label: 'Produk', action: () => widget.navigate(2)),
            QuickIcon(icon: Icons.build_circle_outlined, color: const Color(0xFFE66D13), label: 'Service', action: () => widget.navigate(3)),
            QuickIcon(icon: Icons.smartphone_rounded, color: const Color(0xFF217FE9), label: 'Pulsa & Data', action: () => widget.open(const DigitalScreen())),
            QuickIcon(icon: Icons.people_alt_rounded, color: const Color(0xFF784CE8), label: 'Pelanggan', action: () => widget.open(const CustomersScreen())),
            QuickIcon(icon: Icons.bar_chart_rounded, color: const Color(0xFF43867F), label: 'Laporan', action: () => widget.open(const ReportsScreen())),
            QuickIcon(icon: Icons.payments_rounded, color: const Color(0xFFE65759), label: 'Pengeluaran', action: () => widget.open(const ExpensesScreen())),
            QuickIcon(icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF2256B3), label: 'Saldo Kas', action: () => widget.open(const CashScreen())),
            QuickIcon(icon: Icons.task_alt_rounded, color: const Color(0xFF64758E), label: 'Tugas Toko', action: () => widget.open(const StoreNotesScreen())),
          ],
        ),
        const SizedBox(height: 21),
        Surface(child: Row(children: [
          Container(padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: (data['low_stock']! > 0 ? Colors.orange : Colors.green).withOpacity(.12),
              borderRadius: BorderRadius.circular(15)),
            child: Icon(data['low_stock']! > 0 ? Icons.warning_amber_rounded : Icons.verified_rounded,
              color: data['low_stock']! > 0 ? Colors.orange : Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['low_stock']! > 0 ? '${data['low_stock']} produk stok menipis' : 'Stok dalam kondisi aman',
              style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('Periksa batas minimum stok', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          ])),
          IconButton(onPressed: () => widget.open(const InventoryScreen(lowOnly: true)),
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17)),
        ])),
        const SizedBox(height: 17),
        const _OfflineBanner(),
      ]));
    },
  );
}

class _Welcome extends StatelessWidget {
  final VoidCallback onTap;
  const _Welcome({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 11 ? 'Selamat pagi' : now.hour < 15 ? 'Selamat siang' : now.hour < 18 ? 'Selamat sore' : 'Selamat malam';
    return Surface(child: Row(children: [
      Container(width: 52, height: 52,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD5E9FF), Color(0xFFF0F6FF)]),
          borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.storefront_rounded, size: 28, color: brandBlue)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$greeting!', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 3),
        Text('Semangat mengelola AGAN PONSEL', style: TextStyle(
          fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      IconButton(tooltip: 'Segarkan', onPressed: onTap, icon: const Icon(Icons.refresh_rounded)),
    ]));
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: brandBlue.withOpacity(.07), borderRadius: BorderRadius.circular(15)),
    child: const Row(children: [
      Icon(Icons.offline_bolt_rounded, color: brandBlue, size: 19),
      SizedBox(width: 10),
      Expanded(child: Text('Mode Offline Aktif • Data tersimpan di Android ini',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
    ]),
  );
}


class _DailyGoal extends StatelessWidget {
  final int revenue;
  const _DailyGoal({required this.revenue});
  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: SharedPreferences.getInstance(), builder: (context, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      final target = int.tryParse(snap.data!.getString('daily_sales_target') ?? '1000000') ?? 1000000;
      if (target <= 0) return const SizedBox.shrink();
      final double progress = (revenue / target).clamp(0.0, 1.0).toDouble();
      return Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, size: 18, color: brandBlue),
          const SizedBox(width: 8),
          const Expanded(child: Text('Target omzet hari ini',
            style: TextStyle(fontWeight: FontWeight.w800))),
          Text('${(revenue / target * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w900, color: brandBlue)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(value: progress, minHeight: 9,
            backgroundColor: brandBlue.withValues(alpha: .10))),
        const SizedBox(height: 7),
        Text('${rupiah(revenue)} dari ${rupiah(target)}',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));
    });
}
