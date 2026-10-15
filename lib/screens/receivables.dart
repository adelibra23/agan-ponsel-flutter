import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/receivables_service.dart';
import '../widgets/kit.dart';

/// Pusat piutang dan jatuh tempo; pengingat muncul saat aplikasi dibuka.
class ReceivablesScreen extends StatefulWidget {
  final String initialFilter;
  const ReceivablesScreen({super.key, this.initialFilter = 'Aktif'});
  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  late Future<List<Receivable>> loader;
  late String filter = widget.initialFilter;
  String query = '';
  static const filters = ['Aktif', 'Segera', 'Terlambat', 'Lunas', 'Semua'];

  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => loader = ReceivablesService.all());

  Future<void> add() async {
    final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const CreateReceivableScreen()));
    if (updated == true && mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Piutang Pelanggan'), actions: [
      IconButton(onPressed: refresh, tooltip: 'Segarkan', icon: const Icon(Icons.refresh_rounded)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: add, icon: const Icon(Icons.add_rounded), label: const Text('Piutang Baru')),
    body: FutureBuilder<List<Receivable>>(future: loader, builder: (context, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline,
        title: 'Data piutang belum terbaca', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final all = snap.data!;
      final outstanding = all.fold<int>(0, (n, item) => n + item.remaining);
      final late = all.where((x) => x.overdue).fold<int>(0, (n, x) => n + x.remaining);
      final reminders = all.where((x) => x.overdue || x.dueSoon).length;
      final visible = all.where((x) {
        final matches = '${x.customer} ${x.phone} ${x.description}'.toLowerCase().contains(query.toLowerCase());
        if (!matches) return false;
        switch (filter) {
          case 'Aktif': return !x.isPaid;
          case 'Segera': return x.dueSoon;
          case 'Terlambat': return x.overdue;
          case 'Lunas': return x.isPaid;
          default: return true;
        }
      }).toList();
      return RefreshIndicator(onRefresh: () async { refresh(); await loader; },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
          _DebtHero(outstanding: outstanding, late: late, count: reminders),
          const SizedBox(height: 19),
          SearchBox(hint: 'Cari pelanggan, nomor, atau keterangan...', onChanged: (s) => setState(() => query = s)),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final f in filters) Padding(padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(f), selected: filter == f,
                onSelected: (_) => setState(() => filter = f))),
          ])),
          const SizedBox(height: 17),
          SectionTitle('${visible.length} catatan', subtitle: 'Ketuk untuk cicilan, riwayat dan pengingat'),
          if (visible.isEmpty) const Padding(padding: EdgeInsets.only(top: 58),
            child: EmptyView(icon: Icons.receipt_long_outlined,
              title: 'Belum ada piutang di kategori ini',
              subtitle: 'Tambah piutang baru atau pilih kategori lainnya.')),
          for (final item in visible) ...[
            _ReceivableTile(item: item, onTap: () async {
              await Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => ReceivableDetailScreen(id: item.id)));
              if (mounted) refresh();
            }),
            const SizedBox(height: 10),
          ],
        ]));
    }),
  );
}

class _DebtHero extends StatelessWidget {
  final int outstanding;
  final int late;
  final int count;
  const _DebtHero({required this.outstanding, required this.late, required this.count});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF082F8C), Color(0xFF0865DB), Color(0xFF18A6EB)])),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
        SizedBox(width: 9), Text('TOTAL PIUTANG BELUM DIBAYAR',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11))]),
      const SizedBox(height: 10),
      Text(rupiah(outstanding), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
        fontSize: 28, letterSpacing: -.8)),
      const SizedBox(height: 15),
      Wrap(spacing: 12, runSpacing: 8, children: [
        _HeroChip(Icons.warning_amber_rounded, '${rupiah(late)} terlambat'),
        _HeroChip(Icons.notifications_active_outlined, '$count perlu diingatkan'),
      ]),
    ]),
  );
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroChip(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Colors.white70, size: 15), const SizedBox(width: 5),
    Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
  ]);
}

class _ReceivableTile extends StatelessWidget {
  final Receivable item;
  final VoidCallback onTap;
  const _ReceivableTile({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = item.isPaid ? const Color(0xFF079977)
      : item.overdue ? const Color(0xFFE25753)
      : item.dueSoon ? const Color(0xFFDB8B16) : brandBlue;
    return Surface(padding: EdgeInsets.zero, child: ListTile(
      onTap: onTap, contentPadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: .11),
        child: Icon(item.isPaid ? Icons.check_circle_outline : Icons.schedule_rounded, color: color)),
      title: Text(item.customer, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 3),
        Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(item.dueText, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      ]),
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(rupiah(item.remaining), style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        const Icon(Icons.chevron_right_rounded, size: 18),
      ]),
    ));
  }
}

class CreateReceivableScreen extends StatefulWidget {
  const CreateReceivableScreen({super.key});
  @override
  State<CreateReceivableScreen> createState() => _CreateReceivableScreenState();
}

class _CreateReceivableScreenState extends State<CreateReceivableScreen> {
  final form = GlobalKey<FormState>();
  final customer = TextEditingController();
  final phone = TextEditingController();
  final description = TextEditingController();
  final amount = TextEditingController();
  final notes = TextEditingController();
  DateTime due = DateTime.now().add(const Duration(days: 7));
  bool saving = false;

  @override
  void dispose() {
    for (final c in [customer, phone, description, amount, notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> chooseCustomer() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('customers', orderBy: 'name ASC', limit: 300);
    if (!mounted) return;
    final choice = await showModalBottomSheet<Map<String, Object?>>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: SizedBox(height: 390,
        child: ListView(children: [
          const ListTile(title: Text('Pilih pelanggan tersimpan', style: TextStyle(fontWeight: FontWeight.w900))),
          if (rows.isEmpty) const ListTile(title: Text('Belum ada pelanggan tersimpan')),
          for (final row in rows) ListTile(title: Text('${row['name']}'),
            subtitle: Text('${row['phone']}'),
            onTap: () => Navigator.pop(sheetContext, row)),
        ]))));
    if (choice == null || !mounted) return;
    setState(() {
      customer.text = '${choice['name']}';
      phone.text = '${choice['phone']}';
    });
  }

  Future<void> chooseDue() async {
    final result = await showDatePicker(context: context, initialDate: due,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      helpText: 'Pilih tanggal jatuh tempo');
    if (result != null && mounted) setState(() => due = result);
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false) || saving) return;
    setState(() => saving = true);
    try {
      await ReceivablesService.create(customer: customer.text, phone: phone.text,
        description: description.text, amount: nonNegative(amount.text)!,
        dueDate: due, notes: notes.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) notify(context, 'Gagal menyimpan piutang: $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catat Piutang Baru')),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const PageIntro('Piutang pelanggan', 'Catat siapa yang berutang, jumlah dan batas pembayarannya'),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Informasi pelanggan'),
        OutlinedButton.icon(onPressed: chooseCustomer,
          icon: const Icon(Icons.person_search_rounded), label: const Text('Pilih Pelanggan Tersimpan')),
        const SizedBox(height: 13),
        TextFormField(controller: customer, decoration: inputDecoration('Nama pelanggan *'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        TextFormField(controller: phone, keyboardType: TextInputType.phone,
          decoration: inputDecoration('Nomor WhatsApp / HP')),
      ])),
      const SizedBox(height: 12),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Informasi tagihan'),
        TextFormField(controller: description, decoration: inputDecoration('Keterangan *', hint: 'Contoh: Beli charger & aksesoris'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 12),
        TextFormField(controller: amount, keyboardType: TextInputType.number,
          decoration: inputDecoration('Nominal piutang (Rp) *'),
          validator: (v) { final n = nonNegative(v ?? ''); return n == null || n <= 0 || n > 1000000000 ? 'Masukkan Rp1 – Rp1 miliar' : null; }),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: chooseDue, icon: const Icon(Icons.event_rounded),
          label: Text('Jatuh tempo: ${dateLabel(due.toIso8601String())}')),
        const SizedBox(height: 12),
        TextFormField(controller: notes, maxLines: 2, decoration: inputDecoration('Catatan tambahan (opsional)')),
      ])),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: saving ? null : save,
        icon: const Icon(Icons.save_rounded), label: Text(saving ? 'Menyimpan...' : 'Simpan Piutang')),
      const SizedBox(height: 14),
      const Text('Piutang tidak menambah saldo kas sebelum pembayaran dicatat.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ])),
  );
}

class ReceivableDetailScreen extends StatefulWidget {
  final int id;
  const ReceivableDetailScreen({super.key, required this.id});
  @override
  State<ReceivableDetailScreen> createState() => _ReceivableDetailScreenState();
}

class _ReceivableDetailScreenState extends State<ReceivableDetailScreen> {
  late Future<List<Receivable>> loader;
  late Future<List<Map<String, Object?>>> payments;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() {
    loader = ReceivablesService.all();
    payments = ReceivablesService.payments(widget.id);
  });

  Future<void> recordPayment(Receivable item) async {
    final amount = TextEditingController(text: '${item.remaining}');
    final note = TextEditingController();
    var method = 'Tunai';
    final result = await showAppSheet<(int, String, String)>(context,
      StatefulBuilder(builder: (ctx, update) => Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Catat Pembayaran', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Sisa piutang: ${rupiah(item.remaining)}'),
          const SizedBox(height: 14),
          TextField(controller: amount, keyboardType: TextInputType.number,
            decoration: inputDecoration('Jumlah dibayar (Rp)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: method,
            decoration: inputDecoration('Metode pembayaran'),
            items: const ['Tunai', 'Transfer', 'E-Wallet'].map((s) =>
              DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (value) { if (value != null) update(() => method = value); }),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: inputDecoration('Catatan (opsional)')),
          const SizedBox(height: 18),
          FilledButton(onPressed: () {
            final n = nonNegative(amount.text);
            if (n == null || n <= 0 || n > item.remaining) {
              notify(ctx, 'Nominal harus di antara Rp1 dan ${rupiah(item.remaining)}'); return;
            }
            Navigator.pop(ctx, (n, method, note.text.trim()));
          }, child: const Text('Simpan Pembayaran')),
        ],
      )));
    amount.dispose(); note.dispose();
    if (result == null || !mounted) return;
    try {
      await ReceivablesService.recordPayment(receivableId: item.id,
        amount: result.$1, method: result.$2, note: result.$3);
      if (mounted) { refresh(); notify(context, 'Pembayaran tercatat'); }
    } catch (e) { if (mounted) notify(context, 'Gagal: $e'); }
  }

  Future<void> changeDate(Receivable item) async {
    final old = DateTime.parse(item.dueDate);
    final date = await showDatePicker(context: context, initialDate: old,
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    await ReceivablesService.updateDueDate(item.id, date);
    if (mounted) refresh();
  }

  Future<void> copyReminder(Receivable item) async {
    final prefs = await SharedPreferences.getInstance();
    final style = prefs.getString('reminder_message_template') ?? 'Ramah';
    final message = reminderText(item, style);
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) notify(context, 'Pesan pengingat disalin. Tempel ke chat pelanggan.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail Piutang'), actions: [
      IconButton(tooltip: 'Muat ulang', onPressed: refresh, icon: const Icon(Icons.refresh_rounded))]),
    body: FutureBuilder<List<Receivable>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal membaca tagihan', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final rows = snap.data!.where((r) => r.id == widget.id);
      if (rows.isEmpty) return const EmptyView(icon: Icons.receipt_outlined,
        title: 'Piutang tidak ditemukan', subtitle: 'Data mungkin telah dipulihkan dari backup.');
      final item = rows.first;
      final progress = item.amount == 0 ? 0.0 : item.paid / item.amount;
      final color = item.overdue ? const Color(0xFFE05C54) : const Color(0xFF0879DC);
      return ListView(padding: const EdgeInsets.all(16), children: [
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.customer, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(item.phone.isEmpty ? 'Nomor tidak dicatat' : item.phone,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Divider(height: 24),
          Text(item.description, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('Sisa piutang', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(rupiah(item.remaining), style: TextStyle(color: color, fontSize: 29, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 8, borderRadius: BorderRadius.circular(9)),
          const SizedBox(height: 9),
          Text('Dibayar ${rupiah(item.paid)} dari ${rupiah(item.amount)}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text(item.dueText, style: TextStyle(color: item.overdue ? color : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800)),
          Text('Tanggal: ${dateLabel(item.dueDate)}', style: const TextStyle(fontSize: 12)),
          if (item.notes.isNotEmpty) Text('Catatan: ${item.notes}'),
        ])),
        const SizedBox(height: 13),
        if (!item.isPaid) ...[
          FilledButton.icon(onPressed: () => recordPayment(item),
            icon: const Icon(Icons.payments_rounded), label: const Text('Catat Cicilan / Pelunasan')),
          const SizedBox(height: 9),
          OutlinedButton.icon(onPressed: () => copyReminder(item),
            icon: const Icon(Icons.copy_all_rounded), label: const Text('Salin Pesan Pengingat')),
          const SizedBox(height: 9),
          TextButton.icon(onPressed: () => changeDate(item),
            icon: const Icon(Icons.edit_calendar_rounded), label: const Text('Ubah Jatuh Tempo')),
        ],
        const SizedBox(height: 18),
        const SectionTitle('Riwayat Pembayaran'),
        FutureBuilder<List<Map<String, Object?>>>(future: payments, builder: (ctx, p) {
          if (!p.hasData) return const ScreenLoading();
          if (p.data!.isEmpty) return const Surface(child: Text('Belum ada pembayaran.'));
          return Column(children: [for (final payment in p.data!) ...[
            Surface(child: ListTile(contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF0CA474)),
              title: Text(rupiah(payment['amount'] as int), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${dateLabel(payment['paid_at'] as String)} • ${payment['method']}\n${payment['note']}',
                maxLines: 2), isThreeLine: true)),
            const SizedBox(height: 8),
          ]]);
        }),
      ]);
    }),
  );
}

String reminderText(Receivable item, String style) {
  final due = dateLabel(item.dueDate);
  final remaining = rupiah(item.remaining);
  if (style == 'Singkat') {
    return 'Halo ${item.customer}, pengingat dari AGAN PONSEL: '
      'sisa pembayaran $remaining, jatuh tempo $due. Terima kasih.';
  }
  if (style == 'Formal') {
    return 'Yth. ${item.customer}, kami dari AGAN PONSEL mengingatkan '
      'sisa tagihan ${item.description} sebesar $remaining dengan jatuh tempo $due. '
      'Mohon konfirmasi pembayaran. Terima kasih atas kerja samanya.';
  }
  return 'Halo ${item.customer} 👋 Semoga sehat selalu. '
    'Kami ingin mengingatkan sisa pembayaran untuk ${item.description} '
    'sebesar $remaining (jatuh tempo $due). '
    'Jika sudah dibayar, mohon abaikan pesan ini. Terima kasih 🙏 — AGAN PONSEL';
}

class ReminderCenterScreen extends StatefulWidget {
  const ReminderCenterScreen({super.key});
  @override
  State<ReminderCenterScreen> createState() => _ReminderCenterScreenState();
}

class _ReminderCenterScreenState extends State<ReminderCenterScreen> {
  late Future<List<Receivable>> loader;
  @override
  void initState() { super.initState(); reload(); }
  void reload() => setState(() => loader = ReceivablesService.all());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pusat Pengingat'), actions: [
      IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded))]),
    body: FutureBuilder<List<Receivable>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Pengingat gagal dimuat', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final alerts = snap.data!.where((r) => r.overdue || r.dueSoon).toList()
        ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      return ListView(padding: const EdgeInsets.all(16), children: [
        const PageIntro('Tagihan & jatuh tempo',
          'Daftar otomatis diperbarui berdasarkan tanggal saat kamu membuka aplikasi.'),
        if (alerts.isEmpty) const EmptyView(icon: Icons.verified_rounded,
          title: 'Tidak ada jatuh tempo mendesak', subtitle: 'Semua piutang masih dalam jadwal.'),
        for (final item in alerts) ...[
          _ReceivableTile(item: item, onTap: () async {
            await Navigator.of(context).push<void>(MaterialPageRoute(
              builder: (_) => ReceivableDetailScreen(id: item.id)));
            if (mounted) reload();
          }),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: () async {
          await Navigator.of(context).push<void>(MaterialPageRoute(
            builder: (_) => const ReceivablesScreen(initialFilter: 'Semua')));
          if (mounted) reload();
        }, icon: const Icon(Icons.receipt_long_rounded), label: const Text('Lihat Semua Piutang')),
        const SizedBox(height: 12),
        Text('Pengingat ini ditampilkan di dalam aplikasi. Notifikasi terjadwal di luar aplikasi belum tersedia.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ]);
    }),
  );
}
