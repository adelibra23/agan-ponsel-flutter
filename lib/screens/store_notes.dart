import 'package:flutter/material.dart';
import '../core/database.dart';
import '../core/format.dart';
import '../widgets/kit.dart';

class StoreNotesScreen extends StatefulWidget {
  const StoreNotesScreen({super.key});
  @override
  State<StoreNotesScreen> createState() => _StoreNotesScreenState();
}

class _StoreNotesScreenState extends State<StoreNotesScreen> {
  late Future<List<Map<String, Object?>>> data;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => data = AppDatabase.notes());

  Future<void> add() async {
    final ctrl = TextEditingController();
    final okay = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      showDragHandle: true, builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Catatan / Tugas Toko', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 13),
            TextField(controller: ctrl, maxLines: 3, maxLength: 240,
              decoration: inputDecoration('Contoh: pesan LCD Redmi Note 12')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ])));
    if (okay == true) {
      try { await AppDatabase.addNote(ctrl.text); if (mounted) refresh(); }
      catch (e) { if (mounted) notify(context, '$e'); }
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catatan & Tugas'), actions: [
      IconButton(tooltip: 'Tambah catatan', onPressed: add,
        icon: const Icon(Icons.add_circle_outline_rounded)),
    ]),
    body: FutureBuilder<List<Map<String, Object?>>>(future: data, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline,
        title: 'Gagal memuat tugas', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      if (snap.data!.isEmpty) return const EmptyView(icon: Icons.task_alt_rounded,
        title: 'Belum ada tugas', subtitle: 'Tambahkan tugas toko dari tombol +.');
      return ListView(padding: const EdgeInsets.all(16), children: [
        const PageIntro('Daftar tugas lokal', 'Tandai tugas selesai tanpa internet'),
        for (final item in snap.data!) ...[
          Surface(child: Row(children: [
            Checkbox(value: item['done'] == 1, onChanged: (done) async {
              await AppDatabase.markNote(item['id'] as int, done ?? false);
              if (mounted) refresh();
            }),
            Expanded(child: Text('${item['text']}',
              style: TextStyle(decoration: item['done'] == 1 ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w600))),
            IconButton(tooltip: 'Hapus', onPressed: () async {
              await AppDatabase.deleteNote(item['id'] as int);
              if (mounted) refresh();
            }, icon: const Icon(Icons.delete_outline_rounded)),
          ])),
          const SizedBox(height: 10),
        ],
      ]);
    }),
  );
}
