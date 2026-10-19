import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/printer_service.dart';
import '../widgets/kit.dart';

const serviceStatuses = <String>[
  'Antrian', 'Diterima', 'Dikerjakan', 'Menunggu sparepart', 'Selesai', 'Diambil',
];

Color serviceColor(String status) {
  switch (status) {
    case 'Selesai': return const Color(0xFF09A36E);
    case 'Diambil': return const Color(0xFF6E6F83);
    case 'Dikerjakan': return brandBlue;
    case 'Menunggu sparepart': return const Color(0xFFB65DCE);
    default: return const Color(0xFFE49A1B);
  }
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  late Future<List<Map<String, Object?>>> loader;
  String search = '';
  static const sections = ['Semua', 'Antrian', 'Proses', 'Selesai', 'Diambil'];

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: sections.length, vsync: this);
    tabs.addListener(() { if (mounted) setState(() {}); });
    refresh();
  }

  @override
  void dispose() { tabs.dispose(); super.dispose(); }
  void refresh() => loader = AppDatabase.instance.then((d) => d.query('services', orderBy: 'id DESC'));

  bool inTab(Map<String, Object?> row) {
    final state = '${row['status']}';
    switch (sections[tabs.index]) {
      case 'Antrian': return state == 'Antrian' || state == 'Diterima';
      case 'Proses': return state == 'Dikerjakan' || state == 'Menunggu sparepart';
      case 'Selesai': return state == 'Selesai';
      case 'Diambil': return state == 'Diambil';
      default: return true;
    }
  }

  Future<void> add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ServiceFormScreen()));
    if (saved == true && mounted) setState(refresh);
  }

  Future<void> openDetail(Map<String, Object?> item) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ServiceDetailScreen(id: item['id'] as int)));
    if (mounted) setState(refresh);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: add, backgroundColor: brandBlue, foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded), label: const Text('Service Baru')),
    body: FutureBuilder<List<Map<String, Object?>>>(future: loader, builder: (ctx, snapshot) {
      if (snapshot.hasError) return EmptyView(icon: Icons.error_outline, title: 'Tidak bisa memuat service', subtitle: '${snapshot.error}');
      if (!snapshot.hasData) return const ScreenLoading();
      final all = snapshot.data!;
      final active = all.where((s) => !['Selesai', 'Diambil'].contains(s['status'])).length;
      final done = all.where((s) => s['status'] == 'Selesai').length;
      final filtered = all.where((s) => inTab(s) &&
        '${s['customer']} ${s['device']} ${s['phone']} ${s['imei'] ?? ''}'
          .toLowerCase().contains(search.toLowerCase())).toList();
      return RefreshIndicator(onRefresh: () async { setState(refresh); await loader; },
        child: ListView(key: const PageStorageKey('services-scroll'), padding: const EdgeInsets.fromLTRB(16, 18, 16, 110), children: [
          const PageIntro('Service Center', 'Riwayat perbaikan, status dan pembayaran perangkat'),
          Row(children: [
            Expanded(child: _ServiceSummary(label: 'Tiket', number: all.length,
              icon: Icons.receipt_long_rounded, color: brandBlue)),
            const SizedBox(width: 9),
            Expanded(child: _ServiceSummary(label: 'Aktif', number: active,
              icon: Icons.handyman_rounded, color: const Color(0xFFE48D19))),
            const SizedBox(width: 9),
            Expanded(child: _ServiceSummary(label: 'Selesai', number: done,
              icon: Icons.task_alt_rounded, color: const Color(0xFF00A979))),
          ]),
          const SizedBox(height: 17),
          SearchBox(hint: 'Pelanggan, nomor, tipe HP atau IMEI...',
            onChanged: (value) => setState(() => search = value)),
          const SizedBox(height: 14),
          Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18)),
            child: TabBar(controller: tabs, isScrollable: true, dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(color: brandBlue, borderRadius: BorderRadius.circular(14)),
              labelColor: Colors.white, unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              padding: const EdgeInsets.all(5),
              tabs: sections.map((e) => Tab(text: e, height: 37)).toList())),
          const SizedBox(height: 14),
          AnimatedSwitcher(duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            child: Column(key: ValueKey('${tabs.index}-$search-${filtered.length}'), children: [
              if (filtered.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 72),
                child: EmptyView(icon: Icons.phone_android_rounded,
                  title: 'Belum ada service', subtitle: 'Buat tiket service baru dengan tombol + di bawah.')),
              for (final row in filtered) ...[
                _ServiceTile(item: row, onTap: () => openDetail(row)),
                const SizedBox(height: 10),
              ],
            ])),
        ]));
    }),
  );
}

class _ServiceSummary extends StatelessWidget {
  final String label;
  final int number;
  final IconData icon;
  final Color color;
  const _ServiceSummary({required this.label, required this.number,
    required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Surface(padding: const EdgeInsets.all(11),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 23),
      const SizedBox(height: 12),
      Text('$number', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600, fontSize: 12)),
    ]));
}

class _ServiceTile extends StatelessWidget {
  final Map<String, Object?> item;
  final VoidCallback onTap;
  const _ServiceTile({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final status = '${item['status']}';
    final due = '${item['due_at'] ?? ''}';
    final fee = (item['fee'] as num).toInt();
    final deposit = (item['deposit'] as num?)?.toInt() ?? 0;
    return Surface(padding: EdgeInsets.zero, child: InkWell(
      borderRadius: BorderRadius.circular(22), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('SRV-${(item['id'] as int).toString().padLeft(5, '0')}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
            Pill(status, color: serviceColor(status)),
          ]),
          const Divider(height: 23),
          Row(children: [
            Container(height: 59, width: 59,
              decoration: BoxDecoration(color: brandBlue.withOpacity(.09),
                borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.phone_android_rounded, size: 30, color: brandBlue)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['customer']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${item['device']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${item['issue']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            const Icon(Icons.chevron_right_rounded, size: 21),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Estimasi ${rupiah(fee)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            if (deposit > 0) Pill('DP ${rupiah(deposit)}', color: const Color(0xFF009E78)),
          ]),
          if (due.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(children: [
              const Icon(Icons.event_outlined, size: 14),
              const SizedBox(width: 5),
              Text('Target ${dateLabel(due)}', style: const TextStyle(fontSize: 11)),
            ]),
          ],
        ])),
    ));
  }
}

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key});
  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> with SingleTickerProviderStateMixin {
  late final TabController controller;
  final customer = TextEditingController();
  final phone = TextEditingController();
  final device = TextEditingController();
  final imei = TextEditingController();
  final issue = TextEditingController();
  final accessories = TextEditingController();
  final notes = TextEditingController();
  final technician = TextEditingController();
  final fee = TextEditingController(text: '0');
  final deposit = TextEditingController(text: '0');
  final warranty = TextEditingController(text: '7');
  String priority = 'Normal';
  DateTime? dueDate;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 3, vsync: this);
    controller.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    controller.dispose();
    for (final c in [customer, phone, device, imei, issue, accessories, notes,
      technician, fee, deposit, warranty]) { c.dispose(); }
    super.dispose();
  }

  Future<void> chooseCustomer() async {
    final d = await AppDatabase.instance;
    final rows = await d.query('customers', orderBy: 'name COLLATE NOCASE ASC');
    if (!mounted) return;
    final selection = await showAppSheet<Map<String, Object?>>(context, Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Pilih Pelanggan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (rows.isEmpty) const Text('Belum ada pelanggan tersimpan.'),
        for (final row in rows) ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: Text('${row['name']}'),
          subtitle: Text('${row['phone']}'),
          onTap: () => Navigator.pop(context, row)),
      ],
    ));
    if (selection != null) {
      customer.text = '${selection['name']}';
      phone.text = '${selection['phone']}';
      setState(() {});
    }
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date != null && mounted) setState(() => dueDate = date);
  }

  Future<void> save() async {
    if (customer.text.trim().isEmpty || phone.text.trim().isEmpty) {
      controller.animateTo(0); notify(context, 'Nama dan nomor HP pelanggan wajib diisi'); return;
    }
    if (device.text.trim().isEmpty || issue.text.trim().isEmpty) {
      controller.animateTo(1); notify(context, 'Perangkat dan keluhan wajib diisi'); return;
    }
    final price = nonNegative(fee.text);
    final down = nonNegative(deposit.text);
    final warrantyDays = nonNegative(warranty.text);
    if (price == null || down == null || down > price || warrantyDays == null) {
      controller.animateTo(2); notify(context, 'Nominal DP tidak boleh melebihi estimasi; periksa angka'); return;
    }
    setState(() => saving = true);
    try {
      await AppDatabase.createService({
        'customer': customer.text.trim(), 'phone': phone.text.trim(),
        'device': device.text.trim(), 'imei': imei.text.trim(),
        'issue': issue.text.trim(), 'accessories': accessories.text.trim(),
        'notes': notes.text.trim(), 'technician': technician.text.trim(),
        'fee': price, 'deposit': down,
        'payment_status': price > 0 && down == price ? 'Lunas' : 'Belum Lunas',
        'priority': priority,
        'due_at': dueDate?.toIso8601String() ?? '',
        'warranty_days': warrantyDays,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { notify(context, 'Gagal menyimpan: $e'); setState(() => saving = false); }
    }
  }

  Widget textInput(TextEditingController c, String title, {int lines = 1,
    TextInputType? keyboard, IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, maxLines: lines,
      keyboardType: keyboard,
      decoration: inputDecoration(title, icon: icon)),
  );

  Widget tabPage(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
    children: children);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Service Baru', style: TextStyle(fontWeight: FontWeight.w900))),
    body: SafeArea(child: Column(children: [
      Container(padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Formulir Penerimaan', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Isi data dalam tiga langkah, tanpa koneksi internet.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 13),
          TabBar(controller: controller, dividerColor: Colors.transparent,
            labelColor: Colors.white, unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(color: brandBlue, borderRadius: BorderRadius.circular(13)),
            indicatorPadding: const EdgeInsets.all(3),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            tabs: const [
              Tab(height: 55, icon: Icon(Icons.person_rounded, size: 17), text: 'Pelanggan'),
              Tab(height: 55, icon: Icon(Icons.smartphone_rounded, size: 17), text: 'Perangkat'),
              Tab(height: 55, icon: Icon(Icons.payments_rounded, size: 17), text: 'Biaya'),
            ]),
        ])),
      Expanded(child: TabBarView(controller: controller, children: [
        tabPage([
          const SectionTitle('Data pelanggan'),
          OutlinedButton.icon(onPressed: chooseCustomer,
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('Pilih dari Daftar Pelanggan')),
          const SizedBox(height: 13),
          textInput(customer, 'Nama pelanggan *', icon: Icons.person_outline_rounded),
          textInput(phone, 'Nomor HP *', keyboard: TextInputType.phone, icon: Icons.phone_outlined),
          Surface(child: Text('Jika pelanggan baru, masukkan data langsung. Data tiket tetap tersimpan di SQLite lokal.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ]),
        tabPage([
          const SectionTitle('Informasi perangkat'),
          textInput(device, 'Merek & tipe HP *', icon: Icons.smartphone_rounded),
          textInput(imei, 'IMEI / Serial (opsional)', icon: Icons.qr_code_2_rounded),
          textInput(issue, 'Keluhan / kerusakan *', lines: 3, icon: Icons.build_circle_outlined),
          textInput(accessories, 'Kelengkapan saat diterima', lines: 2,
            icon: Icons.inventory_2_outlined),
          textInput(notes, 'Kondisi fisik / catatan teknisi', lines: 3,
            icon: Icons.notes_rounded),
        ]),
        tabPage([
          const SectionTitle('Biaya & pengerjaan'),
          textInput(fee, 'Estimasi biaya (Rp) *', keyboard: TextInputType.number,
            icon: Icons.sell_outlined),
          textInput(deposit, 'DP / pembayaran diterima (Rp)', keyboard: TextInputType.number,
            icon: Icons.payments_outlined),
          textInput(technician, 'Teknisi penanggung jawab', icon: Icons.engineering_outlined),
          textInput(warranty, 'Garansi service (hari)', keyboard: TextInputType.number,
            icon: Icons.verified_outlined),
          const Text('Prioritas pengerjaan', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          SegmentedButton<String>(showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'Normal', label: Text('Normal')),
              ButtonSegment(value: 'Penting', label: Text('Penting')),
              ButtonSegment(value: 'Urgent', label: Text('Urgent')),
            ], selected: {priority},
            onSelectionChanged: (v) => setState(() => priority = v.first)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: chooseDate,
            icon: const Icon(Icons.event_rounded),
            label: Text(dueDate == null ? 'Atur Target Selesai' : 'Target ${dateLabel(dueDate!.toIso8601String())}')),
        ]),
      ])),
      Container(padding: const EdgeInsets.fromLTRB(17, 11, 17, 12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: Row(children: [
          OutlinedButton(onPressed: controller.index == 0 ? null : () => controller.animateTo(controller.index - 1),
            child: const Text('Kembali')),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(
            onPressed: saving ? null : (controller.index == 2 ? save : () => controller.animateTo(controller.index + 1)),
            icon: Icon(controller.index == 2 ? Icons.save_rounded : Icons.arrow_forward_rounded),
            label: Text(saving ? 'Menyimpan...' : controller.index == 2 ? 'Simpan Tiket Service' : 'Selanjutnya'))),
        ])),
    ])),
  );
}

class ServiceDetailScreen extends StatefulWidget {
  final int id;
  const ServiceDetailScreen({super.key, required this.id});
  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late Future<Map<String, Object?>?> loader;
  @override
  void initState() { super.initState(); reload(); }
  void reload() => loader = load();

  Future<Map<String, Object?>?> load() async {
    final rows = await (await AppDatabase.instance).query('services',
      where: 'id=?', whereArgs: [widget.id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> changeStatus(Map<String, Object?> row) async {
    final note = TextEditingController();
    var next = '${row['status']}';
    final result = await showAppSheet<(String, String)>(context,
      StatefulBuilder(builder: (ctx, update) => Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Perbarui Status Service', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 13),
          for (final item in serviceStatuses) ...[
            RadioListTile<String>(title: Text(item), value: item, groupValue: next,
              onChanged: (value) { if (value != null) update(() => next = value); }),
          ],
          TextField(controller: note, maxLines: 2,
            decoration: inputDecoration('Catatan perubahan status (opsional)')),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(ctx, (next, note.text.trim())),
            child: const Text('Simpan Status')),
        ],
      )));
    note.dispose();
    if (result == null) return;
    try {
      await AppDatabase.changeServiceStatus(widget.id, result.$1, note: result.$2);
      if (mounted) { setState(reload); notify(context, 'Status service berhasil diperbarui'); }
    } catch (e) { if (mounted) notify(context, 'Gagal: $e'); }
  }

  Future<void> editPayment(Map<String, Object?> row) async {
    final fee = TextEditingController(text: '${row['fee']}');
    final deposit = TextEditingController(text: '${row['deposit'] ?? 0}');
    final input = await showAppSheet<(int, int)>(context, Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pembayaran Service', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(controller: fee, keyboardType: TextInputType.number,
          decoration: inputDecoration('Total biaya service (Rp)')),
        const SizedBox(height: 12),
        TextField(controller: deposit, keyboardType: TextInputType.number,
          decoration: inputDecoration('Total DP / pembayaran diterima (Rp)')),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {
          final total = nonNegative(fee.text);
          final paid = nonNegative(deposit.text);
          if (total == null || paid == null || paid > total) {
            notify(context, 'Pembayaran harus 0 sampai nilai estimasi'); return;
          }
          Navigator.pop(context, (total, paid));
        }, child: const Text('Simpan Pembayaran')),
      ],
    ));
    fee.dispose(); deposit.dispose();
    if (input == null) return;
    try {
      await AppDatabase.updateServicePayment(widget.id, fee: input.$1, deposit: input.$2);
      if (mounted) { setState(reload); notify(context, 'Pembayaran diperbarui'); }
    } catch (e) { if (mounted) notify(context, 'Gagal: $e'); }
  }

  Future<void> printTicket(Map<String, Object?> row) async {
    try { await AganPrinter.printService(row);
      if (mounted) notify(context, 'Tiket service dikirim ke printer');
    } catch (e) { if (mounted) notify(context, 'Tidak bisa mencetak: $e'); }
  }

  Future<void> copyTicket(Map<String, Object?> row) async {
    final total = (row['fee'] as num).toInt();
    final paid = (row['deposit'] as num?)?.toInt() ?? 0;
    final text = '''AGAN PONSEL - SERVICE HP
Tiket: SRV-${row['id']}
Pelanggan: ${row['customer']}
HP: ${row['phone']}
Perangkat: ${row['device']}
IMEI: ${row['imei'] ?? '-'}
Keluhan: ${row['issue']}
Kelengkapan: ${row['accessories'] ?? '-'}
Status: ${row['status']}
Estimasi: ${rupiah(total)}
DP: ${rupiah(paid)}
Sisa: ${rupiah(total - paid)}''';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) notify(context, 'Teks tiket berhasil disalin');
  }

  Widget field(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 112, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      Expanded(child: Text('${value ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700))),
    ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Tiket SRV-${widget.id.toString().padLeft(5, '0')}',
      style: const TextStyle(fontWeight: FontWeight.w900))),
    body: FutureBuilder<Map<String, Object?>?>(future: loader, builder: (ctx, snapshot) {
      if (snapshot.hasError) return EmptyView(icon: Icons.error_outline,
        title: 'Gagal membuka tiket', subtitle: '${snapshot.error}');
      if (!snapshot.hasData) {
        if (snapshot.connectionState == ConnectionState.done) return const EmptyView(
          icon: Icons.search_off, title: 'Tiket tidak ditemukan', subtitle: 'Tiket mungkin sudah dihapus');
        return const ScreenLoading();
      }
      final data = snapshot.data!;
      final fee = (data['fee'] as num).toInt();
      final paid = (data['deposit'] as num?)?.toInt() ?? 0;
      final status = '${data['status']}';
      return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 50), children: [
        Container(padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [Color(0xFF0539B4), Color(0xFF0996EA)])),
          child: Row(children: [
            const Icon(Icons.smartphone_rounded, size: 36, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['device']}', style: const TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.w900)),
              Text('${data['customer']}', style: const TextStyle(color: Colors.white70)),
            ])),
          ])),
        const SizedBox(height: 13),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Status Pengerjaan', style: Theme.of(context).textTheme.titleMedium)),
            Pill(status, color: serviceColor(status)),
          ]),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(onPressed: () => changeStatus(data),
            icon: const Icon(Icons.fact_check_outlined), label: const Text('Ubah Status')),
        ])),
        const SizedBox(height: 13),
        const SectionTitle('Perangkat & pelanggan'),
        Surface(child: Column(children: [
          field('Nama', data['customer']), field('Nomor HP', data['phone']),
          field('IMEI / Serial', data['imei']), field('Perangkat', data['device']),
          field('Keluhan', data['issue']), field('Kelengkapan', data['accessories']),
          field('Kondisi / catatan', data['notes']), field('Teknisi', data['technician']),
          field('Prioritas', data['priority']),
          field('Target selesai', '${data['due_at'] ?? ''}'.isEmpty ? '-' : dateLabel('${data['due_at']}')),
          field('Garansi', '${data['warranty_days'] ?? 0} hari'),
        ])),
        const SizedBox(height: 14),
        const SectionTitle('Biaya service'),
        Surface(child: Column(children: [
          field('Estimasi', rupiah(fee)), field('Dibayar / DP', rupiah(paid)),
          field('Sisa pembayaran', rupiah(fee - paid)),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => editPayment(data), icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Catat Pembayaran / Koreksi Biaya'))),
        ])),
        const SizedBox(height: 14),
        const SectionTitle('Riwayat pekerjaan'),
        FutureBuilder<List<Map<String, Object?>>>(future: AppDatabase.serviceEvents(widget.id), builder: (c, s) {
          if (!s.hasData) return const ScreenLoading();
          return Surface(child: Column(children: [
            if (s.data!.isEmpty) const Text('Belum ada perubahan status sejak migrasi versi lama.'),
            for (final e in s.data!) ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline, color: serviceColor('${e['status']}')),
              title: Text('${e['status']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${dateLabel('${e['created_at']}')} ${timeLabel('${e['created_at']}')}\n${e['note']}'),
              isThreeLine: '${e['note']}'.isNotEmpty),
          ]));
        }),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => printTicket(data),
          icon: const Icon(Icons.print_rounded), label: const Text('Cetak Tiket Service')),
        const SizedBox(height: 7),
        OutlinedButton.icon(onPressed: () => copyTicket(data),
          icon: const Icon(Icons.copy_rounded), label: const Text('Salin Tiket Service')),
      ]);
    }),
  );
}
