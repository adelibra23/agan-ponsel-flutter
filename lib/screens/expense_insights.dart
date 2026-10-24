import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../services/expense_insights_service.dart';
import '../services/expenses_service.dart';

/// Spending-only insights. Revenue and profit are not inferred here.
class ExpenseInsightsScreen extends StatefulWidget {
  final Future<bool> Function(ExpenseEntry entry)? onRepeat;
  const ExpenseInsightsScreen({super.key, this.onRepeat});
  @override
  State<ExpenseInsightsScreen> createState() => _ExpenseInsightsScreenState();
}

class _InsightData {
  final ExpenseInsights insights;
  final ExpenseBudgetSettings budget;
  final List<ExpenseCategory> categories;
  const _InsightData(this.insights, this.budget, this.categories);
}

class _ExpenseInsightsScreenState extends State<ExpenseInsightsScreen> {
  late Future<_InsightData> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  void refresh() {
    future = _load();
    if (mounted) setState(() {});
  }

  Future<_InsightData> _load() async {
    final entries = await ExpensesService.list();
    final categories = await ExpensesService.categories(showArchived: true);
    final budget = await ExpenseBudgetSettings.load();
    return _InsightData(ExpenseInsights.calculate(entries, DateTime.now()), budget, categories);
  }

  Future<void> changeBudget() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const ExpenseBudgetScreen()));
    if (mounted) refresh();
  }

  Future<void> repeat(ExpenseEntry source) async {
    final didCreate = await widget.onRepeat?.call(source) ?? false;
    if (didCreate && mounted) refresh();
  }

  void copyReport(_InsightData data) {
    final summary = data.insights;
    final names = {for (final c in data.categories) c.id: c.name};
    final ranked = summary.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final now = DateTime.now();
    final lines = <String>[
      'AGAN PONSEL • RINGKASAN PENGELUARAN',
      'Bulan: ${now.month.toString().padLeft(2, '0')}/${now.year}',
      'Total: ${rupiah(summary.currentMonthTotal)}',
      'Bulan lalu: ${rupiah(summary.previousMonthTotal)}',
      'Jumlah transaksi: ${summary.transactionCount}',
      'Batas anggaran: ${data.budget.overall == 0 ? 'Belum diatur' : rupiah(data.budget.overall)}',
      'Status: ${ExpenseInsights.budgetStatus(summary.currentMonthTotal, data.budget.overall)}',
      'Kategori:',
      for (final c in ranked) '- ${names[c.key] ?? 'Lainnya'}: ${rupiah(c.value)}',
      'Dibuat dari data lokal AGAN PONSEL.',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ringkasan pengeluaran disalin')));
  }

  Widget _budgetProgress(int spent, int budget, Color color) {
    if (budget <= 0) return const SizedBox.shrink();
    final ratio = ExpenseInsights.usage(spent, budget);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(),
        color: ratio >= 1 ? Colors.redAccent : color, minHeight: 7,
        borderRadius: BorderRadius.circular(8)),
      const SizedBox(height: 5),
      Text('${ExpenseInsights.budgetStatus(spent, budget)} • ${rupiah(budget)}',
        style: TextStyle(fontSize: 11, color: ratio >= .8
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 17, 0, 9),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Insight Pengeluaran'), actions: [
      IconButton(onPressed: refresh, tooltip: 'Muat ulang', icon: const Icon(Icons.refresh_rounded)),
    ]),
    body: FutureBuilder<_InsightData>(future: future, builder: (context, snap) {
      if (snap.hasError) return Center(child: Padding(
        padding: const EdgeInsets.all(18), child: Text('Insight belum bisa dimuat: ${snap.error}')));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final data = snap.data!;
      final insight = data.insights;
      final names = {for (final cat in data.categories) cat.id: cat.name};
      final styles = {for (final cat in data.categories) cat.id: Color(cat.colorValue)};
      final ranked = insight.categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final accent = Theme.of(context).colorScheme.primary;
      final highest = insight.months.fold<int>(1, (p, m) => m.total > p ? m.total : p);
      final changed = insight.currentMonthTotal - insight.previousMonthTotal;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PENGELUARAN BULAN INI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(rupiah(insight.currentMonthTotal),
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${insight.transactionCount} transaksi',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('Bulan lalu: ${rupiah(insight.previousMonthTotal)}',
            style: const TextStyle(fontSize: 12)),
          Text(changed == 0 ? 'Tidak berubah dari bulan lalu' :
            '${changed > 0 ? 'Naik' : 'Turun'} ${rupiah(changed.abs())} dibanding bulan lalu',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: changed > 0 ? Theme.of(context).colorScheme.error : accent)),
          _budgetProgress(insight.currentMonthTotal, data.budget.overall, accent),
          const SizedBox(height: 11),
          OutlinedButton.icon(onPressed: changeBudget,
            icon: const Icon(Icons.tune_rounded), label: const Text('Atur Anggaran Bulanan')),
        ]))),
        _section('Tren 6 bulan terakhir'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          for (final month in insight.months) Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${month.month.month.toString().padLeft(2, '0')}/${month.month.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(rupiah(month.total), style: const TextStyle(fontSize: 12)),
              ]),
              const SizedBox(height: 5),
              LinearProgressIndicator(value: (month.total / highest).clamp(0.0, 1.0).toDouble(),
                borderRadius: BorderRadius.circular(6), minHeight: 9),
            ])),
        ]))),
        _section('Pengeluaran per kategori • bulan ini'),
        if (ranked.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16),
          child: Text('Belum ada pengeluaran bulan ini.'))),
        for (final item in ranked) Card(child: Padding(
          padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(names[item.key] ?? 'Lainnya',
                style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(rupiah(item.value), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: insight.currentMonthTotal == 0 ? 0.0 :
              item.value / insight.currentMonthTotal,
              color: styles[item.key] ?? accent, minHeight: 6,
              borderRadius: BorderRadius.circular(7)),
            if (item.key != null) _budgetProgress(item.value,
              data.budget.byCategory[item.key] ?? 0, styles[item.key] ?? accent),
          ]))),
        _section('Sering dicatat • pintasan input'),
        if (insight.frequent.isEmpty) const Card(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Pengeluaran yang dicatat beberapa kali akan muncul di sini.'))),
        for (final item in insight.frequent) Card(child: ListTile(
          title: Text(item.source.description),
          subtitle: Text('${item.times} kali • ${rupiah(item.source.amount)}'),
          trailing: const Icon(Icons.add_circle_outline_rounded),
          onTap: widget.onRepeat == null ? null : () => repeat(item.source),
        )),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: () => copyReport(data),
          icon: const Icon(Icons.copy_rounded), label: const Text('Salin Ringkasan Bulanan')),
        const SizedBox(height: 12),
        const Text('Insight hanya menghitung pengeluaran yang tercatat. '
          'Ini bukan perhitungan laba atau saldo rekening. '
          'Peringatan anggaran tampil saat halaman ini dibuka, bukan alarm Android.',
          style: TextStyle(fontSize: 11)),
      ]);
    }),
  );
}

class ExpenseBudgetScreen extends StatefulWidget {
  const ExpenseBudgetScreen({super.key});
  @override
  State<ExpenseBudgetScreen> createState() => _ExpenseBudgetScreenState();
}

class _ExpenseBudgetScreenState extends State<ExpenseBudgetScreen> {
  late Future<void> loading;
  final overall = TextEditingController();
  final controllers = <int, TextEditingController>{};
  final categories = <ExpenseCategory>[];
  var saving = false;
  Map<int, int> original = {};

  @override
  void initState() {
    super.initState();
    loading = load();
  }

  Future<void> load() async {
    final prefs = await ExpenseBudgetSettings.load();
    final cats = await ExpensesService.categories(showArchived: true);
    overall.text = prefs.overall == 0 ? '' : prefs.overall.toString();
    original = Map.of(prefs.byCategory);
    categories.addAll(cats.where((c) => !c.archived));
    for (final cat in categories) {
      final amount = prefs.byCategory[cat.id] ?? 0;
      controllers[cat.id] = TextEditingController(text: amount == 0 ? '' : amount.toString());
    }
  }

  int? parse(TextEditingController controller) {
    final s = controller.text.trim();
    if (s.isEmpty) return 0;
    final amount = int.tryParse(s);
    if (amount == null || amount < 0 || amount > ExpenseBudgetSettings.maxRupiah) return null;
    return amount;
  }

  Future<void> save() async {
    final overallValue = parse(overall);
    final limits = Map<int, int>.of(original);
    if (overallValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batas total tidak valid')));
      return;
    }
    for (final entry in controllers.entries) {
      final value = parse(entry.value);
      if (value == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Periksa nominal kategori')));
        return;
      }
      if (value == 0) { limits.remove(entry.key); } else { limits[entry.key] = value; }
    }
    setState(() => saving = true);
    try {
      await ExpenseBudgetSettings(overall: overallValue, byCategory: limits).save();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  void dispose() {
    overall.dispose();
    for (final c in controllers.values) { c.dispose(); }
    super.dispose();
  }

  Widget amountField(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixText: 'Rp ',
        hintText: '0 = tanpa batas'),
    ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Anggaran Bulanan')),
    body: FutureBuilder<void>(future: loading, builder: (ctx, snap) {
      if (snap.hasError) return Center(child: Text('Tidak bisa membuka anggaran: ${snap.error}'));
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 34), children: [
        Text('Atur batas belanja bulanan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Batas berlaku untuk setiap bulan kalender dan tidak mengurangi kas secara otomatis.'),
        const SizedBox(height: 20),
        amountField(overall, 'Batas semua pengeluaran'),
        const SizedBox(height: 6),
        Text('Batas per kategori', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final cat in categories) amountField(controllers[cat.id]!, cat.name),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Menyimpan...' : 'Simpan Anggaran')),
        const SizedBox(height: 12),
        const Text('Peringatan 80% dan 100% terlihat dalam Insight Pengeluaran. '
          'Pengaturan ikut tercadangkan bersama profil aplikasi.',
          style: TextStyle(fontSize: 11)),
      ]);
    }),
  );
}
