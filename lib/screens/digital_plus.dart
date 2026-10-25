import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../services/store_plus_service.dart';
import '../widgets/kit.dart';

const digitalKinds = <String>[
  'Telkomsel', 'XL', 'Indosat', 'Tri', 'Smartfren', 'Axis',
  'Transfer Bank', 'Tarik Tunai', 'E-Wallet', 'Token PLN', 'Google Play', 'Game', 'Lainnya',
];

class DigitalPlusScreen extends StatefulWidget {
  const DigitalPlusScreen({super.key});
  @override
  State<DigitalPlusScreen> createState() => _DigitalPlusScreenState();
}

class _DigitalPlusScreenState extends State<DigitalPlusScreen> {
  late Future<List<Map<String, Object?>>> transactions;
  String search = '';
  String status = 'Semua';
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => transactions = StorePlusService.digital());
  Future<void> add() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const _DigitalEditor()));
    if (saved == true && mounted) refresh();
  }
  Future<void> view(Map<String, Object?> row) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _DigitalDetail(row: row)));
    if (mounted) refresh();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pulsa & Transaksi Digital'), actions: [
      IconButton(onPressed: add, tooltip: 'Tambah Transaksi',
        icon: const Icon(Icons.add_circle_outline_rounded))]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: add, icon: const Icon(Icons.add), label: const Text('Catat Digital')),
    body: FutureBuilder<List<Map<String, Object?>>>(future: transactions,
      builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Text('Gagal memuat: ${snap.error}'));
        if (!snap.hasData) return const ScreenLoading();
        final all = snap.data!;
        final shown = all.where((r) =>
          (status == 'Semua' || '${r['status']}' == status) &&
          '${r['operator']} ${r['destination']} ${r['reference_code']}'
            .toLowerCase().contains(search.toLowerCase())).toList();
        final fee = all.where((r) => r['status'] == 'Selesai')
          .fold<int>(0, (sum, r) => sum + (r['fee'] as int));
        return RefreshIndicator(onRefresh: () async { refresh(); await transactions; },
          child: ListView(key: const PageStorageKey('digital-v28-scroll'),
            padding: const EdgeInsets.fromLTRB(16,16,16,100), children: [
            const PageIntro('Transaksi digital lokal',
              'Pencatatan manual. Tidak melakukan top up atau transfer sungguhan.'),
            Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Admin transaksi selesai: ${rupiah(fee)}',
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text('${all.length} transaksi • ${all.where((e)=>e['status']=='Menunggu').length} menunggu'),
            ])),
            const SizedBox(height: 12),
            TextField(onChanged: (v) => setState(() => search = v),
              decoration: inputDecoration('Cari nomor, operator, referensi', icon: Icons.search)),
            const SizedBox(height: 12),
            SizedBox(height: 43, child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final value in ['Semua', ...StorePlusService.statuses]) Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(value), selected: value == status,
                  onSelected: (_) => setState(() => status = value))),
            ])),
            const SizedBox(height: 10),
            if (shown.isEmpty) const Padding(padding: EdgeInsets.all(24),
              child: Text('Transaksi tidak ditemukan.')),
            for (final row in shown) Padding(padding: const EdgeInsets.only(bottom: 9),
              child: Surface(child: ListTile(contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.sim_card_outlined)),
                onTap: () => view(row),
                title: Text('${row['operator']} • ${rupiah(row['nominal'] as int)}'),
                subtitle: Text('${row['destination']}\n${dateLabel('${row['created_at']}')} • ${row['status']}'),
                isThreeLine: true, trailing: Text('+${rupiah(row['fee'] as int)}')))),
          ])));
      }),
  );
}

class _DigitalEditor extends StatefulWidget {
  const _DigitalEditor();
  @override
  State<_DigitalEditor> createState() => _DigitalEditorState();
}

class _DigitalEditorState extends State<_DigitalEditor> {
  final destination = TextEditingController();
  final nominal = TextEditingController();
  final fee = TextEditingController(text: '5000');
  final note = TextEditingController();
  final reference = TextEditingController();
  String service = digitalKinds.first;
  String status = 'Selesai';
  String method = 'Tunai';
  bool busy = false;
  @override
  void dispose() {
    destination.dispose(); nominal.dispose(); fee.dispose(); note.dispose();
    reference.dispose(); super.dispose();
  }
  Future<void> save() async {
    if (busy) return;
    final n = nonNegative(nominal.text);
    final f = nonNegative(fee.text);
    if (n == null || f == null) { notify(context, 'Nominal atau biaya admin tidak valid'); return; }
    setState(() => busy = true);
    try {
      await StorePlusService.addDigital(service: service, destination: destination.text,
        nominal: n, fee: f, status: status, method: method,
        note: note.text, reference: reference.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) notify(context, '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catat Transaksi Digital')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Hanya untuk pencatatan, tidak memproses pembayaran eksternal.'),
      const SizedBox(height: 13),
      DropdownButtonFormField<String>(value: service,
        decoration: inputDecoration('Jenis layanan'),
        items: [for (final s in digitalKinds) DropdownMenuItem(value:s, child: Text(s))],
        onChanged: (v) { if(v!=null)setState(()=>service=v); }),
      const SizedBox(height: 12),
      TextField(controller: destination, decoration: inputDecoration('Nomor tujuan / pelanggan')),
      const SizedBox(height: 12),
      TextField(controller: nominal, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: inputDecoration('Nominal layanan (Rp)')),
      const SizedBox(height: 12),
      TextField(controller: fee, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: inputDecoration('Biaya admin (Rp)')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: status,
        decoration: inputDecoration('Status transaksi'),
        items: [for(final s in StorePlusService.statuses)
          DropdownMenuItem(value:s, child:Text(s))],
        onChanged: (v) {if(v!=null)setState(()=>status=v);}),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: method,
        decoration: inputDecoration('Metode pembayaran'),
        items: [for(final s in ['Tunai','Transfer','E-Wallet','Lainnya'])
          DropdownMenuItem(value:s, child:Text(s))],
        onChanged: (v) {if(v!=null)setState(()=>method=v);}),
      const SizedBox(height: 12),
      TextField(controller: reference, maxLength: 100,
        decoration: inputDecoration('Nomor referensi (opsional)')),
      const SizedBox(height: 12),
      TextField(controller: note, maxLength: 500, maxLines: 3,
        decoration: inputDecoration('Catatan transaksi (opsional)')),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: busy ? null : save,
        icon: const Icon(Icons.save), label: const Text('Simpan Transaksi')),
    ]),
  );
}

class _DigitalDetail extends StatefulWidget {
  final Map<String, Object?> row;
  const _DigitalDetail({required this.row});
  @override
  State<_DigitalDetail> createState() => _DigitalDetailState();
}
class _DigitalDetailState extends State<_DigitalDetail> {
  late String status = '${widget.row['status'] ?? 'Selesai'}';
  late final note = TextEditingController(text: '${widget.row['note'] ?? ''}');
  late final ref = TextEditingController(text: '${widget.row['reference_code'] ?? ''}');
  bool busy = false;
  @override
  void dispose(){ note.dispose(); ref.dispose(); super.dispose(); }
  Future<void> save() async {
    setState(() => busy = true);
    try {
      await StorePlusService.updateDigital(widget.row['id'] as int,
        status: status,note: note.text,reference: ref.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {if (mounted) notify(context, '$e');}
    finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> share() async {
    final row = widget.row;
    final text = 'AGAN PONSEL • TRANSAKSI DIGITAL\n'
      'Jenis: ${row['operator']}\nTujuan: ${row['destination']}\n'
      'Nominal: ${rupiah(row['nominal'] as int)}\n'
      'Admin: ${rupiah(row['fee'] as int)}\n'
      'Status: $status\nReferensi: ${ref.text}\nCatatan: ${note.text}';
    try { await SharePlus.instance.share(ShareParams(text: text)); }
    catch (e) {if (mounted) notify(context, '$e');}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Digital #${widget.row['id']}'), actions: [
      IconButton(tooltip: 'Bagikan detail', onPressed: share, icon: const Icon(Icons.share_outlined))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${widget.row['operator']}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 9),
        Text('Tujuan: ${widget.row['destination']}'),
        Text('Nominal: ${rupiah(widget.row['nominal'] as int)}'),
        Text('Biaya Admin: ${rupiah(widget.row['fee'] as int)}'),
        Text('Dibuat: ${widget.row['created_at']}'),
        Text('Metode: ${widget.row['payment_method'] ?? 'Tunai'}'),
      ])),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(value: status,
        decoration: inputDecoration('Perbarui status'),
        items: [for (final s in StorePlusService.statuses)
          DropdownMenuItem(value:s,child:Text(s))],
        onChanged: (v) {if(v!=null)setState(()=>status=v);}),
      const SizedBox(height: 12),
      TextField(controller: ref, decoration: inputDecoration('Nomor referensi')),
      const SizedBox(height: 12),
      TextField(controller: note, maxLines: 3, maxLength: 500,
        decoration: inputDecoration('Catatan / alasan status')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: busy ? null : save,
        icon: const Icon(Icons.save), label: const Text('Simpan Status & Catatan')),
      const SizedBox(height: 20),
      const SectionTitle('Riwayat perubahan'),
      FutureBuilder<List<Map<String, Object?>>>(future:
        StorePlusService.digitalEvents(widget.row['id'] as int), builder:(ctx,snap){
          if(!snap.hasData) return const SizedBox.shrink();
          if(snap.data!.isEmpty) return const Text('Belum ada perubahan.');
          return Column(children: [for (final e in snap.data!) ListTile(
            title: Text('${e['old_status']} → ${e['new_status']}'),
            subtitle: Text('${e['created_at']}\nRef: ${e['old_reference']} → ${e['new_reference']}'),
          )]);
        }),
    ]),
  );
}
