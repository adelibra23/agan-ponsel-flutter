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
import 'receivables.dart';
import '../services/receivables_service.dart';
import 'agana_agent.dart';

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
        const SizedBox(height: 12),
        _AganaCard(onTap: () => widget.open(const AganaAgentScreen())),
        const SizedBox(height: 13),
        BalanceCard(onOpen: () => widget.open(const CashScreen())),
        const SizedBox(height: 12),
        _DebtReminderCard(onOpen: () => widget.open(const ReminderCenterScreen()),
          onAll: () => widget.open(const ReceivablesScreen())),
        const SizedBox(height: 12),
        _DailyGoal(revenue: data['revenue']!),
        const SizedBox(height: 18),
        const SectionTitle('Ringkasan hari ini', subtitle: 'Pantau performa toko secara langsung'),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: 1.44,
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
            QuickIcon(icon: Icons.receipt_long_rounded, color: const Color(0xFFCB713E), label: 'Piutang', action: () => widget.open(const ReceivablesScreen())),
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
        const _LocalDataBanner(),
      ]));
    },
  );
}

class _AganaCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AganaCard({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF34358B), Color(0xFF6858DC)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(children: [
        CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.auto_awesome_rounded, color: Colors.white)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tanya AGANA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 3),
          Text('Cek piutang, stok, service, atau catat data toko',
            style: TextStyle(color: Color(0xFFE4DFFF), fontSize: 11.5)),
        ])),
        Icon(Icons.arrow_forward_rounded, color: Colors.white),
      ]),
    ),
  );
}

class _Welcome extends StatelessWidget {
  final VoidCallback onTap;
  const _Welcome({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 11 ? 'Selamat pagi' : now.hour < 15
        ? 'Selamat siang' : now.hour < 18 ? 'Selamat sore' : 'Selamat malam';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).colorScheme;
    final textColor = palette.onSurface;
    final date = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: dark
            ? const [Color(0xFF1B3351), Color(0xFF1A2639)]
            : const [Color(0xFFE6F2FF), Color(0xFFFFFFFF)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.outlineVariant.withValues(alpha: .65)),
      ),
      child: Row(children: [
        Container(width: 53, height: 53,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF2B4872) : const Color(0xFFD5E8FF),
            borderRadius: BorderRadius.circular(17)),
          child: Icon(Icons.storefront_rounded, size: 28,
            color: dark ? const Color(0xFFBBD6FF) : brandBlue)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greeting!', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900,
              fontSize: 17.5, letterSpacing: -.2)),
          const SizedBox(height: 3),
          Text('AGAN PONSEL • $date', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.4, fontWeight: FontWeight.w600,
              color: palette.onSurfaceVariant)),
          const SizedBox(height: 5),
          Text('Semua aktivitas toko dalam satu tempat',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: palette.onSurfaceVariant)),
        ])),
        IconButton(tooltip: 'Segarkan ringkasan', onPressed: onTap,
          style: IconButton.styleFrom(backgroundColor:
            palette.primary.withValues(alpha: .10)),
          icon: Icon(Icons.refresh_rounded, color: palette.primary, size: 21)),
      ]),
    );
  }
}

class _LocalDataBanner extends StatelessWidget {
  const _LocalDataBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: brandBlue.withOpacity(.07), borderRadius: BorderRadius.circular(15)),
    child: const Row(children: [
      Icon(Icons.verified_user_rounded, color: brandBlue, size: 19),
      SizedBox(width: 10),
      Expanded(child: Text('Data toko tersimpan di perangkat ini',
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
      final palette = Theme.of(context).colorScheme;
      final progress = (revenue / target).clamp(0.0, 1.0).toDouble();
      final percent = (revenue / target * 100).round();
      return Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: palette.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.flag_rounded, color: palette.primary, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Target omzet hari ini', style: TextStyle(
              color: palette.onSurface, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(percent >= 100 ? 'Target tercapai!' : 'Menuju target harian',
              style: TextStyle(fontSize: 11, color: palette.onSurfaceVariant)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: palette.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10)),
            child: Text('$percent%', style: TextStyle(color: palette.primary,
              fontSize: 12, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 15),
        ClipRRect(borderRadius: BorderRadius.circular(9),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => LinearProgressIndicator(
              value: value, minHeight: 9,
              backgroundColor: palette.primary.withValues(alpha: .10),
              color: palette.primary))),
        const SizedBox(height: 10),
        Text('${rupiah(revenue)} dari ${rupiah(target)}',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
            color: palette.onSurfaceVariant)),
      ]));
    });
}

class _DebtReminderCard extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onAll;
  const _DebtReminderCard({required this.onOpen, required this.onAll});
  @override
  Widget build(BuildContext context) => FutureBuilder<ReceivableSummary>(
    future: ReceivablesService.summary(), builder: (context, snap) {
      if (!snap.hasData || snap.data!.openCount == 0) return const SizedBox.shrink();
      final s = snap.data!;
      final active = s.alertCount > 0;
      final accent = active ? const Color(0xFFD88719) : Theme.of(context).colorScheme.primary;
      return Surface(child: Column(children: [
        Row(children: [
          CircleAvatar(backgroundColor: accent.withValues(alpha: .12),
            child: Icon(Icons.notifications_active_outlined, color: accent)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(active ? '${s.alertCount} pengingat jatuh tempo' : 'Piutang pelanggan',
              style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('${rupiah(s.totalOutstanding)} belum dibayar',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          IconButton(tooltip: 'Lihat pengingat', onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17)),
        ]),
        if (active) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onAll,
            icon: const Icon(Icons.receipt_long_outlined), label: const Text('Kelola Piutang'))),
        ],
      ]));
    });
}
