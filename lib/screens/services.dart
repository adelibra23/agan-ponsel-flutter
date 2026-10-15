import 'package:flutter/material.dart';
import '../core/database.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late Future<List<Map<String, Object?>>> loader;
  String status = 'Semua';
  String search = '';
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => loader = AppDatabase.instance.then((d) => d.query('services', orderBy: 'id DESC')));

  Future<void> addService() async {
    final added = await showAppSheet<bool>(context, const _ServiceForm());
    if (added == true) refresh();
  }

  Future<void> editStatus(Map<String, Object?> row) async {
    final result = await showAppSheet<String>(context, Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Status Pengerjaan', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Text('${row['customer']} • ${row['device']}',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 14),
      for (final item in ['Diterima', 'Antrian', 'Dikerjakan', 'Menunggu sparepart', 'Selesai'])
        ListTile(
          leading: Icon(item == row['status'] ? Icons.radio_button_checked : Icons.radio_button_off,
            color: item == row['status'] ? brandBlue : null),
          title: Text(item),
          onTap: () => Navigator.pop(context, item)),
    ]));
    if (result != null && result != row['status']) {
      await (await AppDatabase.instance).update('services', {'status': result},
        where: 'id=?', whereArgs: [row['id']]);
      if (mounted) refresh();
    }
  }

  Color colorFor(String text) {
    switch (text) {
      case 'Selesai': return const Color(0xFF00A96F);
      case 'Dikerjakan': return brandBlue;
      case 'Menunggu sparepart': return const Color(0xFFDD7A0B);
      default: return const Color(0xFFDF8A06);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: FutureBuilder<List<Map<String, Object?>>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal memuat service', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final rows = snap.data!.where((r) =>
        (status == 'Semua' || r['status'] == status) &&
        '${r['customer']} ${r['device']} ${r['phone']}'.toLowerCase().contains(search.toLowerCase())).toList();
      return RefreshIndicator(onRefresh: () async { refresh(); await loader; },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 85), children: [
          const PageIntro('Service HP', 'Pantau perangkat dari masuk sampai selesai'),
          SearchBox(hint: 'Cari pelanggan, HP atau nomor...', onChanged: (v) => setState(() => search = v)),
          const SizedBox(height: 11),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final tag in ['Semua', 'Antrian', 'Diterima', 'Dikerjakan', 'Menunggu sparepart', 'Selesai'])
              Padding(padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(label: Text(tag), selected: status == tag,
                  onSelected: (_) => setState(() => status = tag))),
          ])),
          const SizedBox(height: 13),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 70),
            child: EmptyView(icon: Icons.handyman_outlined, title: 'Belum ada service',
              subtitle: 'Tambah tiket service dari tombol di bawah.')),
          for (final row in rows) ...[
            Surface(child: InkWell(onTap: () => editStatus(row),
              borderRadius: BorderRadius.circular(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('#SRV-${(row['id'] as int).toString().padLeft(4, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
                  Pill('${row['status']}', color: colorFor('${row['status']}')),
                ]),
                const Divider(height: 23),
                Row(children: [
                  Container(height: 58, width: 58,
                    decoration: BoxDecoration(color: brandBlue.withOpacity(.1), borderRadius: BorderRadius.circular(17)),
                    child: const Icon(Icons.smartphone_rounded, size: 30, color: brandBlue)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${row['customer']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('${row['device']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${row['issue']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  const Icon(Icons.chevron_right_rounded),
                ]),
                const SizedBox(height: 11),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Estimasi: ${rupiah(row['fee'] as int)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(dateLabel(row['created_at'] as String), style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ]))),
            const SizedBox(height: 10),
          ],
        ]));
    }),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: addService, backgroundColor: brandBlue, foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded), label: const Text('Service Baru')),
  );
}

class _ServiceForm extends StatefulWidget {
  const _ServiceForm();
  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  final customer = TextEditingController();
  final phone = TextEditingController();
  final device = TextEditingController();
  final issue = TextEditingController();
  final fee = TextEditingController(text: '0');
  bool saving = false;

  @override
  void dispose() {
    customer.dispose(); phone.dispose(); device.dispose(); issue.dispose(); fee.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = nonNegative(fee.text);
    if (customer.text.trim().isEmpty || device.text.trim().isEmpty || amount == null) {
      notify(context, 'Isi nama pelanggan, perangkat, dan biaya yang valid'); return;
    }
    setState(() => saving = true);
    try {
      await (await AppDatabase.instance).insert('services', {
        'customer': customer.text.trim(), 'phone': phone.text.trim(),
        'device': device.text.trim(), 'issue': issue.text.trim(),
        'fee': amount, 'status': 'Antrian', 'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => saving = false); notify(context, 'Gagal menyimpan: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Terima Service HP', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      TextField(controller: customer, decoration: inputDecoration('Nama pelanggan')),
      const SizedBox(height: 10),
      TextField(controller: phone, keyboardType: TextInputType.phone,
        decoration: inputDecoration('Nomor HP pelanggan')),
      const SizedBox(height: 10),
      TextField(controller: device, decoration: inputDecoration('Merek dan tipe perangkat')),
      const SizedBox(height: 10),
      TextField(controller: issue, maxLines: 2, decoration: inputDecoration('Keluhan / kerusakan')),
      const SizedBox(height: 10),
      TextField(controller: fee, keyboardType: TextInputType.number,
        decoration: inputDecoration('Estimasi biaya (Rp)')),
      const SizedBox(height: 18),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Menyimpan...' : 'Simpan Tiket Service')),
    ],
  );
}
