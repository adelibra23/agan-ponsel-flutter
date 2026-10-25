import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database.dart';
import 'store_finance_plus.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';
import '../widgets/premium_cash_card.dart';
import 'settings/cash_card_settings.dart';

// AGAN_PONSEL_PREMIUM_CASH_CARD_V29
/// Existing public widget name retained for the dashboard and other callers.
class BalanceCard extends StatelessWidget {
  final VoidCallback onOpen;
  const BalanceCard({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) => PremiumCashCard(
    onOpen: onOpen,
    onCustomize: () => Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const CashCardSettingsScreen())),
  );
}

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});
  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  late Future<List<Map<String, Object?>>> entries;

  @override
  void initState() { super.initState(); refresh(); }

  void refresh() => setState(() => entries = AppDatabase.cashHistory());

  void showAppearance() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const CashCardSettingsScreen()));
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
      IconButton(tooltip: 'Analisis kas & ekspor CSV',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const CashInsightsScreen())),
        icon: const Icon(Icons.assessment_outlined)),
      IconButton(tooltip: 'Atur target omzet', onPressed: setDailyTarget,
        icon: const Icon(Icons.flag_outlined)),
      IconButton(tooltip: 'Pilihan Kartu Premium', onPressed: showAppearance,
        icon: const Icon(Icons.palette_outlined)),
    ]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      PremiumCashCard(onCustomize: showAppearance),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => adjust(true),
          icon: const Icon(Icons.add), label: const Text('Kas Masuk'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: () => adjust(false),
          icon: const Icon(Icons.remove), label: const Text('Kas Keluar'))),
      ]),
      const SizedBox(height: 17),
      Surface(child: Text('Saldo = penjualan Tunai + pembayaran piutang Tunai + penyesuaian kas − seluruh pengeluaran tercatat. Transfer, e-wallet, DP service dan saldo rekening tidak otomatis dihitung.',
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
