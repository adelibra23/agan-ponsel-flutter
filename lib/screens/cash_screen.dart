import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';

/// Private, locally remembered balance visibility. It is NOT a bank balance.
class BalanceCard extends StatefulWidget {
  final VoidCallback onOpen;
  const BalanceCard({super.key, required this.onOpen});
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool visible = false;
  late Future<int> total;

  @override
  void initState() {
    super.initState();
    total = AppDatabase.cashBalance();
    loadVisibility();
  }

  Future<void> loadVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => visible = prefs.getBool('cash_balance_visible') ?? false);
  }

  Future<void> toggle() async {
    final next = !visible;
    setState(() => visible = next);
    await (await SharedPreferences.getInstance()).setBool('cash_balance_visible', next);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0C1C52), Color(0xFF0754DC), Color(0xFF168DF0)]),
      boxShadow: [BoxShadow(color: brandBlue.withValues(alpha: .17), blurRadius: 15, offset: const Offset(0, 6))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 19),
        const SizedBox(width: 8),
        const Expanded(child: Text('SALDO KAS TERCATAT',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: .8))),
        IconButton(tooltip: visible ? 'Sembunyikan saldo' : 'Tampilkan saldo',
          onPressed: toggle, icon: Icon(visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: Colors.white, size: 22)),
      ]),
      FutureBuilder<int>(future: total, builder: (context, snap) =>
        AnimatedSwitcher(duration: const Duration(milliseconds: 240),
          child: Text(visible ? (snap.hasData ? rupiah(snap.data!) : 'Menghitung...') : 'Rp ••••••••',
            key: ValueKey('${visible}-${snap.data}'),
            style: const TextStyle(color: Colors.white, fontSize: 28,
              letterSpacing: -.8, fontWeight: FontWeight.w900)))),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Text('Tunai + penyesuaian − pengeluaran',
          style: TextStyle(color: Colors.white70, fontSize: 10))),
        TextButton.icon(onPressed: widget.onOpen,
          style: TextButton.styleFrom(foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('Detail', style: TextStyle(fontSize: 12))),
      ]),
    ]),
  );
}

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});
  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  late Future<int> balance;
  late Future<List<Map<String, Object?>>> entries;
  bool visible = false;

  @override
  void initState() { super.initState(); refresh(); loadPrefs(); }
  void refresh() => setState(() {
    balance = AppDatabase.cashBalance();
    entries = AppDatabase.cashHistory();
  });
  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => visible = prefs.getBool('cash_balance_visible') ?? false);
  }
  Future<void> toggle() async {
    setState(() => visible = !visible);
    await (await SharedPreferences.getInstance()).setBool('cash_balance_visible', visible);
  }

  Future<void> setDailyTarget() async {
    final pref = await SharedPreferences.getInstance();
    if (!mounted) return;
    final ctrl = TextEditingController(text: pref.getString('daily_sales_target') ?? '1000000');
    final ok = await showModalBottomSheet<bool>(context: context, showDragHandle: true,
      isScrollControlled: true, builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Target Omzet Harian', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: ctrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: inputDecoration('Target per hari (Rp)')),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan Target')),
          ])));
    if (ok == true) {
      final target = int.tryParse(ctrl.text);
      if (target != null && target > 0 && target <= 1000000000000) {
        await pref.setString('daily_sales_target', target.toString());
        if (mounted) notify(context, 'Target harian tersimpan');
      } else if (mounted) { notify(context, 'Target harus antara Rp1 dan Rp1 triliun'); }
    }
    ctrl.dispose();
  }

  Future<void> adjust(bool incoming) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final valid = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      showDragHandle: true, builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(incoming ? 'Tambah Kas' : 'Kurangi Kas', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: amount, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: inputDecoration('Nominal (Rp)')),
          const SizedBox(height: 11),
          TextField(controller: note, maxLength: 100, decoration: inputDecoration('Keterangan')),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan Penyesuaian')),
        ])),
      ));
    if (valid == true) {
      try {
        final value = int.tryParse(amount.text) ?? 0;
        if (value <= 0) throw const FormatException('Nominal harus lebih dari nol');
        await AppDatabase.adjustCash(incoming ? value : -value, note.text);
        if (mounted) { refresh(); notify(context, 'Penyesuaian kas tersimpan'); }
      } catch (e) { if (mounted) notify(context, '$e'); }
    }
    amount.dispose(); note.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dompet Kas Toko'), actions: [
      IconButton(tooltip: 'Atur target omzet', onPressed: setDailyTarget,
        icon: const Icon(Icons.flag_outlined)),
    ]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(colors: [Color(0xFF0E2B83), brandBlue, Color(0xFF0C9FE6)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SALDO KAS LOKAL', style: TextStyle(fontWeight: FontWeight.w800,
            fontSize: 11, letterSpacing: 1.3, color: Colors.white70)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FutureBuilder<int>(future: balance, builder: (ctx, snap) =>
              Text(visible ? (snap.hasData ? rupiah(snap.data!) : 'Memuat...') : 'Rp ••••••••',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)))),
            IconButton(onPressed: toggle,
              icon: Icon(visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: Colors.white)),
          ]),
          const SizedBox(height: 8),
          const Text('Bukan saldo bank/e-wallet. Tidak tersinkron dengan transaksi eksternal.',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => adjust(true),
          icon: const Icon(Icons.add), label: const Text('Kas Masuk'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: () => adjust(false),
          icon: const Icon(Icons.remove), label: const Text('Kas Keluar'))),
      ]),
      const SizedBox(height: 17),
      Surface(child: Text('Saldo = penjualan dengan pembayaran Tunai + setoran/penyesuaian − seluruh pengeluaran tercatat. Penjualan lama tanpa metode pembayaran, DP service, transfer, dan saldo rekening tidak otomatis dihitung.',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
      const SizedBox(height: 11),
      OutlinedButton.icon(onPressed: setDailyTarget,
        icon: const Icon(Icons.flag_rounded), label: const Text('Atur Target Omzet Harian')),
      const SizedBox(height: 19),
      const SectionTitle('Riwayat penyesuaian kas', subtitle: 'Setoran dan pengambilan kas manual'),
      FutureBuilder<List<Map<String, Object?>>>(future: entries, builder: (ctx, snap) {
        if (snap.hasError) return Text('Tidak bisa memuat: ${snap.error}');
        if (!snap.hasData) return const ScreenLoading();
        if (snap.data!.isEmpty) return const Surface(child: Text('Belum ada penyesuaian manual.'));
        return Column(children: [for (final item in snap.data!) ...[
          Surface(child: Row(children: [
            CircleAvatar(backgroundColor: ((item['delta'] as int) >= 0
              ? Colors.green : Colors.orange).withValues(alpha: .1),
              child: Icon((item['delta'] as int) >= 0 ? Icons.south_west : Icons.north_east,
                color: (item['delta'] as int) >= 0 ? Colors.green : Colors.orange)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['note']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${item['created_at']}'.split('T').first,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            Text('${(item['delta'] as int) >= 0 ? '+' : '−'}${rupiah((item['delta'] as int).abs())}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ])),
          const SizedBox(height: 9),
        ]]);
      }),
    ]),
  );
}
