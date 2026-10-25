import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../services/store_plus_service.dart';
import '../widgets/kit.dart';

class StoreNotesScreen extends StatefulWidget {
  const StoreNotesScreen({super.key});
  @override
  State<StoreNotesScreen> createState() => _StoreNotesScreenState();
}

class _StoreNotesScreenState extends State<StoreNotesScreen> {
  late Future<List<Map<String, Object?>>> loader;
  String category = 'Semua';
  String search = '';
  bool openOnly = false;

  @override
  void initState() { super.initState(); reload(); }
  void reload() => setState(() => loader = StorePlusService.notes());

  Future<void> edit([Map<String, Object?>? row]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _NoteEditor(initial: row)));
    if (saved == true && mounted) reload();
  }

  Future<void> share(Map<String, Object?> note) async {
    final text = 'AGAN PONSEL • CATATAN TOKO\n'
      'Kategori: ${note['category']}\n'
      'Prioritas: ${note['priority']}\n'
      'Tenggat: ${(note['due_at'] as String? ?? '').isEmpty ? '-' : note['due_at']}\n'
      'Status: ${note['done'] == 1 ? 'Selesai' : 'Belum selesai'}\n\n'
      '${note['text']}';
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: 'Catatan AGAN PONSEL'));
    } catch (e) {
      if (mounted) notify(context, 'Tidak dapat membagikan catatan: $e');
    }
  }

  Future<void> remove(Map<String, Object?> note) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus catatan?'),
      content: const Text('Tindakan ini tidak bisa dibatalkan.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus'))]));
    if (yes != true) return;
    try {
      await StorePlusService.removeNote(note['id'] as int);
      if (mounted) reload();
    } catch (e) { if (mounted) notify(context, '$e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catatan & Tugas'), actions: [
      IconButton(tooltip: 'Tambah catatan', onPressed: () => edit(),
        icon: const Icon(Icons.add_circle_outline_rounded))]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Tugas Baru')),
    body: FutureBuilder<List<Map<String, Object?>>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal memuat tugas',
        subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final all = snap.data!;
      final rows = all.where((r) =>
        (category == 'Semua' || r['category'] == category) &&
        (!openOnly || r['done'] != 1) &&
        '${r['text']} ${r['category']}'.toLowerCase().contains(search.toLowerCase())).toList();
      final dueToday = DateTime.now().toIso8601String().substring(0, 10);
      final overdue = all.where((r) => r['done'] != 1 &&
        (r['due_at'] as String? ?? '').isNotEmpty &&
        (r['due_at'] as String).compareTo(dueToday) < 0).length;
      return RefreshIndicator(onRefresh: () async { reload(); await loader; },
        child: ListView(key: const PageStorageKey('notes-v28-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 95), children: [
          const PageIntro('Tugas operasional',
            'Edit, kategorikan, sematkan dan bagikan. Semua tersimpan di HP.'),
          Row(children: [
            Expanded(child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('${all.where((r) => r['done'] != 1).length}',
                style: Theme.of(context).textTheme.headlineSmall),
                const Text('Belum selesai')]))),
            const SizedBox(width: 10),
            Expanded(child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('$overdue', style: Theme.of(context).textTheme.headlineSmall),
                const Text('Lewat tenggat')]))),
          ]),
          const SizedBox(height: 14),
          TextField(onChanged: (v) => setState(() => search = v),
            decoration: inputDecoration('Cari catatan / tugas', icon: Icons.search)),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
            title: const Text('Hanya belum selesai'), value: openOnly,
            onChanged: (v) => setState(() => openOnly = v)),
          SizedBox(height: 43, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in ['Semua', ...StorePlusService.categories]) Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(label: Text(c), selected: category == c,
                onSelected: (_) => setState(() => category = c))),
          ])),
          const SizedBox(height: 16),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 42),
            child: EmptyView(icon: Icons.task_alt, title: 'Tidak ada catatan',
              subtitle: 'Tambah catatan atau ubah filter.')),
          for (final note in rows) ...[
            Surface(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: note['done'] == 1, onChanged: (v) async {
                await StorePlusService.setNoteDone(note['id'] as int, v ?? false);
                if (mounted) reload();
              }),
              Expanded(child: InkWell(onTap: () => edit(note), child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${note['text']}', maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700,
                      decoration: note['done'] == 1 ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Chip(label: Text('${note['category'] ?? 'Umum'}'), visualDensity: VisualDensity.compact),
                    Chip(label: Text('${note['priority'] ?? 'Normal'}'), visualDensity: VisualDensity.compact),
                    if (note['pinned'] == 1) const Icon(Icons.push_pin_rounded, size: 16),
                  ]),
                  if ('${note['due_at'] ?? ''}'.isNotEmpty) Text(
                    'Tenggat: ${note['due_at']}', style: TextStyle(fontSize: 12,
                      color: note['done'] != 1 && '${note['due_at']}'.compareTo(dueToday) < 0
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
                ])))),
              PopupMenuButton<String>(tooltip: 'Opsi catatan',
                onSelected: (action) async {
                  if (action == 'edit') await edit(note);
                  if (action == 'share') await share(note);
                  if (action == 'copy') {
                    await Clipboard.setData(ClipboardData(text: '${note['text']}'));
                    if (mounted) notify(context, 'Catatan disalin');
                  }
                  if (action == 'delete') await remove(note);
                }, itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit catatan')),
                  PopupMenuItem(value: 'share', child: Text('Bagikan')),
                  PopupMenuItem(value: 'copy', child: Text('Salin teks')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ]),
            ])),
            const SizedBox(height: 10),
          ],
        ]));
    }),
  );
}

class _NoteEditor extends StatefulWidget {
  final Map<String, Object?>? initial;
  const _NoteEditor({this.initial});
  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final controller = TextEditingController(text: '${widget.initial?['text'] ?? ''}');
  late String category = '${widget.initial?['category'] ?? 'Umum'}';
  late String priority = '${widget.initial?['priority'] ?? 'Normal'}';
  late String due = '${widget.initial?['due_at'] ?? ''}';
  late bool pinned = widget.initial?['pinned'] == 1;
  bool busy = false;

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  Future<void> date() async {
    final selected = await showDatePicker(context: context,
      initialDate: DateTime.tryParse(due) ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (selected != null) setState(() => due = selected.toIso8601String().substring(0, 10));
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await StorePlusService.saveNote(id: widget.initial?['id'] as int?,
        text: controller.text, category: category, priority: priority,
        dueAt: due, pinned: pinned);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) notify(context, '$e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.initial == null ? 'Catat Tugas Baru' : 'Edit Catatan')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      TextField(controller: controller, maxLines: 5, maxLength: 500,
        decoration: inputDecoration('Isi catatan atau tugas')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: category,
        decoration: inputDecoration('Kategori'), items: [for (final c in StorePlusService.categories)
          DropdownMenuItem(value: c, child: Text(c))],
        onChanged: (v) { if (v != null) setState(() => category = v); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: priority,
        decoration: inputDecoration('Prioritas'), items: [for (final p in StorePlusService.priorities)
          DropdownMenuItem(value: p, child: Text(p))],
        onChanged: (v) { if (v != null) setState(() => priority = v); }),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: date, icon: const Icon(Icons.event),
        label: Text(due.isEmpty ? 'Atur tanggal tenggat' : 'Tenggat $due')),
      if (due.isNotEmpty) TextButton(onPressed: () => setState(() => due = ''),
        child: const Text('Hapus tanggal tenggat')),
      SwitchListTile.adaptive(title: const Text('Sematkan di atas'),
        value: pinned, onChanged: (v) => setState(() => pinned = v)),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: busy ? null : save,
        icon: const Icon(Icons.save_outlined),
        label: Text(busy ? 'Menyimpan...' : 'Simpan Catatan')),
    ]),
  );
}
