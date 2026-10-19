import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contact_picker.dart';

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
        child: ListView(key: const PageStorageKey('receivable-list-scroll'), padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
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

class _DebtRow {
  final TextEditingController label;
  final TextEditingController qty;
  final TextEditingController price;

  _DebtRow({String title = '', int quantity = 1, int unitPrice = 0})
      : label = TextEditingController(text: title),
        qty = TextEditingController(text: '$quantity'),
        price = TextEditingController(text: unitPrice == 0 ? '' : '$unitPrice');

  void dispose() { label.dispose(); qty.dispose(); price.dispose(); }
}

/// Form create/edit memakai sumber data sama, total hasil perhitungan item.
/// Riwayat cicilan lama tetap dipertahankan oleh ReceivablesService.editDetailed.
class CreateReceivableScreen extends StatefulWidget {
  final Receivable? existing;
  final List<ReceivableLine>? initialItems;
  const CreateReceivableScreen({super.key, this.existing, this.initialItems});

  @override
  State<CreateReceivableScreen> createState() => _CreateReceivableScreenState();
}

class _CreateReceivableScreenState extends State<CreateReceivableScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController customer;
  late final TextEditingController phone;
  late final TextEditingController description;
  late final TextEditingController notes;
  late DateTime due;
  final List<_DebtRow> rows = [];
  bool saving = false;
  bool get editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    customer = TextEditingController(text: existing?.customer ?? '');
    phone = TextEditingController(text: existing?.phone ?? '');
    description = TextEditingController(text: existing?.description ?? '');
    notes = TextEditingController(text: existing?.notes ?? '');
    due = existing == null
        ? DateTime.now().add(const Duration(days: 7))
        : DateTime.parse(existing.dueDate);
    final initial = widget.initialItems ?? const <ReceivableLine>[];
    if (initial.isNotEmpty) {
      for (final item in initial) {
        rows.add(_DebtRow(title: item.description,
          quantity: item.qty, unitPrice: item.unitPrice));
      }
    } else if (existing != null) {
      // Piutang lama tanpa tabel rincian ditampilkan sebagai satu baris.
      rows.add(_DebtRow(title: existing.description, unitPrice: existing.amount));
    } else {
      rows.add(_DebtRow());
    }
  }

  @override
  void dispose() {
    for (final c in [customer, phone, description, notes]) { c.dispose(); }
    for (final row in rows) { row.dispose(); }
    super.dispose();
  }

  int get subtotal {
    var total = 0;
    for (final line in rows) {
      final q = nonNegative(line.qty.text) ?? 0;
      final price = nonNegative(line.price.text) ?? 0;
      total += q * price;
    }
    return total;
  }

  Future<void> chooseCustomer() async {
    final db = await AppDatabase.instance;
    final result = await db.query('customers', orderBy: 'name ASC', limit: 300);
    if (!mounted) return;
    final choice = await showModalBottomSheet<Map<String, Object?>>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: SizedBox(height: 440,
        child: ListView(children: [
          const ListTile(title: Text('Pelanggan Tersimpan',
            style: TextStyle(fontWeight: FontWeight.w900))),
          if (result.isEmpty) const ListTile(title: Text('Belum ada pelanggan')),
          for (final row in result) ListTile(
            title: Text('${row['name']}'), subtitle: Text('${row['phone']}'),
            onTap: () => Navigator.pop(sheetContext, row)),
        ]))));
    if (!mounted || choice == null) return;
    setState(() { customer.text = '${choice['name']}'; phone.text = '${choice['phone']}'; });
  }

  Future<void> chooseContact() async {
    final selected = await Navigator.of(context).push<ContactChoice>(
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()));
    if (!mounted || selected == null) return;
    setState(() {
      customer.text = selected.name;
      phone.text = selected.number.replaceAll(RegExp(r'[^0-9+]'), '');
    });
  }

  Future<void> chooseDue() async {
    final result = await showDatePicker(context: context, initialDate: due,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      helpText: 'Tanggal jatuh tempo piutang');
    if (result != null && mounted) setState(() => due = result);
  }

  List<ReceivableLine> collectItems() => [
    for (final row in rows) ReceivableLine(
      description: row.label.text.trim(),
      qty: nonNegative(row.qty.text) ?? 0,
      unitPrice: nonNegative(row.price.text) ?? -1,
    ),
  ];

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    late final List<ReceivableLine> items;
    try {
      items = collectItems();
      ReceivablesService.calculateTotal(items);
    } catch (e) { notify(context, '$e'); return; }
    setState(() => saving = true);
    try {
      final summary = description.text.trim().isNotEmpty
          ? description.text.trim()
          : items.map((e) => e.description).join(', ');
      if (editing) {
        await ReceivablesService.editDetailed(
          receivableId: widget.existing!.id, customer: customer.text,
          phone: phone.text, description: summary, notes: notes.text,
          dueDate: due, lines: items);
      } else {
        await ReceivablesService.createDetailed(
          customer: customer.text, phone: phone.text,
          description: summary, notes: notes.text, dueDate: due, lines: items);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) notify(context, 'Tidak bisa menyimpan piutang: $e');
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(editing ? 'Edit Detail Piutang' : 'Catat Piutang Baru')),
    body: Form(key: form, child: ListView(
      key: const PageStorageKey('receivable-editor'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        PageIntro(editing ? 'Perbarui catatan' : 'Piutang pelanggan',
          'Pisahkan setiap barang atau jasa agar jumlah tagihan jelas.'),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Informasi pelanggan'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: chooseCustomer,
              icon: const Icon(Icons.people_alt_outlined), label: const Text('Pelanggan Tersimpan')),
            OutlinedButton.icon(onPressed: chooseContact,
              icon: const Icon(Icons.contact_phone_outlined), label: const Text('Cari di Kontak HP')),
          ]),
          const SizedBox(height: 14),
          TextFormField(controller: customer,
            decoration: inputDecoration('Nama pelanggan *', icon: Icons.person_outline),
            validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null),
          const SizedBox(height: 12),
          TextFormField(controller: phone, keyboardType: TextInputType.phone,
            decoration: inputDecoration('Nomor HP / WhatsApp', icon: Icons.phone_outlined)),
          const SizedBox(height: 5),
          Text('Izin kontak hanya diminta saat tombol Cari di Kontak HP ditekan.',
            style: TextStyle(fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        const SizedBox(height: 13),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: SectionTitle('Rincian barang & harga')),
            Text('${rows.length}/30', style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          for (var i = 0; i < rows.length; i++) ...[
            _itemFields(i, rows[i]),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(onPressed: rows.length >= 30 ? null : () =>
            setState(() => rows.add(_DebtRow())),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tambah Baris Barang / Jasa')),
          const Divider(height: 26),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('TOTAL PIUTANG', style: TextStyle(fontWeight: FontWeight.w900)),
            Flexible(child: Text(rupiah(subtotal), textAlign: TextAlign.right,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary))),
          ]),
          if (editing) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('Sudah dibayar ${rupiah(widget.existing!.paid)} • '
              'total baru tidak boleh kurang dari cicilan.',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ])),
        const SizedBox(height: 13),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Jadwal & catatan'),
          TextFormField(controller: description,
            decoration: inputDecoration('Ringkasan tagihan (opsional)',
              hint: 'Otomatis memakai daftar barang jika kosong')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: chooseDue,
            icon: const Icon(Icons.event_available_outlined),
            label: Text('Jatuh tempo: ${dateLabel(due.toIso8601String())}')),
          const SizedBox(height: 12),
          TextFormField(controller: notes, maxLines: 2,
            decoration: inputDecoration('Catatan tambahan (opsional)')),
        ])),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Menyimpan...' : editing ? 'Simpan Perubahan' : 'Simpan Piutang')),
        const SizedBox(height: 10),
        const Text('Piutang tidak menambah saldo kas sampai cicilan dicatat.',
          style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
      ],
    )),
  );

  Widget _itemFields(int index, _DebtRow row) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Item ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w800))),
        if (rows.length > 1) IconButton(
          tooltip: 'Hapus item', icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => setState(() { rows.removeAt(index); row.dispose(); })),
      ]),
      TextFormField(controller: row.label,
        decoration: inputDecoration('Nama barang / jasa *'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Nama item wajib diisi' : null),
      const SizedBox(height: 11),
      Row(children: [
        Expanded(flex: 2, child: TextFormField(controller: row.qty,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: inputDecoration('Jumlah *'),
          onChanged: (_) => setState(() {}),
          validator: (v) { final value = nonNegative(v ?? '');
            return value == null || value <= 0 || value > 10000 ? '1–10.000' : null; },
        )),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: TextFormField(controller: row.price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: inputDecoration('Harga satuan (Rp) *'),
          onChanged: (_) => setState(() {}),
          validator: (v) { final value = nonNegative(v ?? '');
            return value == null || value > 1000000000 ? 'Harga tidak valid' : null; },
        )),
      ]),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerRight,
        child: Text('Subtotal: ${rupiah((nonNegative(row.qty.text) ?? 0) * (nonNegative(row.price.text) ?? 0))}',
          style: const TextStyle(fontWeight: FontWeight.w800))),
    ]),
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
  late Future<List<ReceivableLine>> items;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() {
    loader = ReceivablesService.all();
    payments = ReceivablesService.payments(widget.id);
    items = ReceivablesService.lines(widget.id);
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

  Future<void> editDetails(Receivable item) async {
    try {
      final currentItems = await ReceivablesService.lines(item.id);
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CreateReceivableScreen(
          existing: item, initialItems: currentItems)));
      if (changed == true && mounted) {
        refresh();
        notify(context, 'Detail piutang berhasil diperbarui');
      }
    } catch (e) {
      if (mounted) notify(context, 'Tidak dapat membuka editor: $e');
    }
  }

  Future<void> sendWhatsApp(Receivable item) async {
    final destination = whatsappPhone(item.phone);
    if (destination == null) {
      notify(context, 'Nomor WhatsApp belum valid. Tambahkan melalui Edit Detail.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final message = item.isPaid
      ? 'Halo ${item.customer}, pembayaran untuk ${item.description} di AGAN PONSEL sudah lunas. Terima kasih 🙏'
      : reminderText(item, prefs.getString('reminder_message_template') ?? 'Ramah');
    if (!mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: const Text('Kirim Pengingat ke WhatsApp'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tujuan: ${item.customer} • ${item.phone}'),
            const SizedBox(height: 13),
            Text(message),
            const SizedBox(height: 13),
            const Text('WhatsApp akan dibuka dengan teks terisi. '
              'Pesan baru terkirim setelah kamu menekan Kirim di WhatsApp.',
              style: TextStyle(fontSize: 12)),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buka WhatsApp')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    final uri = Uri.https('wa.me', '/$destination', {'text': message});
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        notify(context, 'WhatsApp tidak dapat dibuka. Coba salin pesan.');
      }
    } catch (e) {
      if (mounted) notify(context, 'Gagal membuka WhatsApp: $e');
    }
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
      return ListView(key: const PageStorageKey('receivable-detail-scroll'),
        padding: const EdgeInsets.all(16), children: [
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
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Rincian Barang & Jasa'),
          FutureBuilder<List<ReceivableLine>>(future: items, builder: (ctx, details) {
            if (!details.hasData) return const ScreenLoading();
            if (details.data!.isEmpty) return const Text('Piutang versi lama. '
              'Tekan Edit Detail untuk mencatat rincian barang dan harga.');
            return Column(children: [
              for (final line in details.data!) Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${line.qty} × ${rupiah(line.unitPrice)}',
                        style: TextStyle(fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                  Text(rupiah(line.total),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                ])),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text('Total Barang', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(rupiah(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w900))]),
            ]);
          }),
        ])),
        const SizedBox(height: 13),
        FilledButton.tonalIcon(onPressed: () => editDetails(item),
          icon: const Icon(Icons.edit_note_rounded), label: const Text('Edit Detail Piutang')),
        const SizedBox(height: 9),
        OutlinedButton.icon(onPressed: () => sendWhatsApp(item),
          icon: const Icon(Icons.send_rounded), label: const Text('Kirim ke WhatsApp')),
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
      return ListView(key: const PageStorageKey('reminder-center-scroll'),
        padding: const EdgeInsets.all(16), children: [
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
