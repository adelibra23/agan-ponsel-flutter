import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../services/expenses_service.dart';

/// Expense management: category CRUD (archival), detailed entry, date/time edit,
/// auditable correction/removal, list filters and portable CSV export.
class ExpensesManagementScreen extends StatefulWidget {
  const ExpensesManagementScreen({super.key});
  @override
  State<ExpensesManagementScreen> createState() => _ExpensesManagementScreenState();
}

class _ExpensesManagementScreenState extends State<ExpensesManagementScreen> {
  late Future<List<ExpenseEntry>> entries;
  String search = '';
  String period = 'Bulan ini';
  int? categoryFilter;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() { if (mounted) setState(() => entries = ExpensesService.list()); }

  List<ExpenseEntry> filtered(List<ExpenseEntry> all) {
    final now = DateTime.now();
    return all.where((e) {
      if (categoryFilter != null && e.categoryId != categoryFilter) return false;
      if (period == 'Hari ini' && (e.date.year != now.year ||
          e.date.month != now.month || e.date.day != now.day)) return false;
      if (period == 'Bulan ini' && (e.date.year != now.year || e.date.month != now.month)) return false;
      if (period == 'Tahun ini' && e.date.year != now.year) return false;
      final q = search.trim().toLowerCase();
      return q.isEmpty || e.description.toLowerCase().contains(q) ||
        e.category.toLowerCase().contains(q) || e.note.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> openEditor([ExpenseEntry? entry]) async {
    final changed = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => ExpenseEditorPage(entry: entry)));
    if (changed == true) refresh();
  }
  Future<void> openDetail(ExpenseEntry entry) async {
    await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => ExpenseDetailPage(id: entry.id)));
    if (mounted) refresh();
  }
  Future<void> openCategories() async {
    await Navigator.push<void>(context,
      MaterialPageRoute(builder: (_) => const ExpenseCategoriesPage()));
    if (mounted) setState(() => categoryFilter = null);
    refresh();
  }

  String csvCell(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';
  Future<void> exportCsv(List<ExpenseEntry> shown) async {
    try {
      final lines = <String>[
        'ID,Tanggal,Waktu,Kategori,Keterangan,Nominal,Metode,Catatan',
        for (final e in shown) [e.id, dateLabel(e.date.toIso8601String()),
          timeLabel(e.date.toIso8601String()), e.category, e.description,
          e.amount, e.method, e.note].map(csvCell).join(','),
      ];
      final bytes = Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}\r\n'));
      final result = await FilePicker.saveFile(dialogTitle: 'Ekspor Pengeluaran ke CSV',
        fileName: 'agan-ponsel-pengeluaran-${todayKey()}.csv', bytes: bytes);
      if (!mounted) return;
      notify(context, result == null ? 'Ekspor dibatalkan' : 'CSV berhasil disimpan');
    } catch (e) { if (mounted) notify(context, 'Ekspor gagal: $e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengeluaran'), actions: [
      IconButton(tooltip: 'Riwayat audit', icon: const Icon(Icons.history),
        onPressed: () => Navigator.push<void>(context,
          MaterialPageRoute(builder: (_) => const ExpenseAuditPage()))),
      IconButton(tooltip: 'Kategori', icon: const Icon(Icons.category_outlined), onPressed: openCategories),
      IconButton(tooltip: 'Tambah pengeluaran', icon: const Icon(Icons.add_circle_outline),
        onPressed: () => openEditor()),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => openEditor(), icon: const Icon(Icons.add_rounded), label: const Text('Catat Pengeluaran')),
    body: FutureBuilder<List<ExpenseEntry>>(future: entries, builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('Gagal memuat pengeluaran: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final all = snap.data!;
      final shown = filtered(all);
      final sum = shown.fold<int>(0, (v, e) => v + e.amount);
      return ListView(key: const PageStorageKey('expense-v2-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(23),
            gradient: const LinearGradient(colors: [Color(0xFF203F88), Color(0xFF3479D4)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TOTAL PENGELUARAN SESUAI FILTER',
              style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: .7)),
            const SizedBox(height: 9),
            Text(rupiah(sum), style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 27)),
            const SizedBox(height: 6),
            Text('${shown.length} transaksi • ${period.toLowerCase()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        const SizedBox(height: 14),
        TextField(onChanged: (v) => setState(() => search = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
            hintText: 'Cari pengeluaran atau catatan',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            isExpanded: true, initialValue: period,
            decoration: const InputDecoration(labelText: 'Periode'),
            items: const ['Hari ini','Bulan ini','Tahun ini','Semua']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) setState(() => period = v); })),
          const SizedBox(width: 9),
          Expanded(child: FutureBuilder<List<ExpenseCategory>>(
            future: ExpensesService.categories(showArchived: true), builder: (ctx, cat) {
              final categories = cat.data ?? <ExpenseCategory>[];
              final exists = categoryFilter == null || categories.any((c) => c.id == categoryFilter);
              return DropdownButtonFormField<int>(isExpanded: true,
                initialValue: exists ? categoryFilter : null,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: [const DropdownMenuItem<int>(value: null, child: Text('Semua kategori')),
                  ...categories.map((c) => DropdownMenuItem<int>(value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis)))],
                onChanged: (v) => setState(() => categoryFilter = v));
            })),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: openCategories,
            icon: const Icon(Icons.edit_note, size: 18), label: const Text('Kelola Kategori'))),
          const SizedBox(width: 9),
          Expanded(child: OutlinedButton.icon(onPressed: shown.isEmpty ? null : () => exportCsv(shown),
            icon: const Icon(Icons.file_download_outlined, size: 18), label: const Text('Ekspor CSV'))),
        ]),
        const SizedBox(height: 13),
        if (shown.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 55),
            child: Center(child: Text('Belum ada pengeluaran pada filter ini.'))),
        for (final e in shown) Padding(padding: const EdgeInsets.only(bottom: 9),
          child: Card(child: ListTile(onTap: () => openDetail(e),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined, size: 20)),
            title: Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${e.category} • ${dateLabel(e.date.toIso8601String())} '
              '${timeLabel(e.date.toIso8601String())}\n${e.method}',
              style: const TextStyle(fontSize: 11.5)),
            isThreeLine: true,
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
              Text(rupiah(e.amount), style: const TextStyle(fontWeight: FontWeight.w800,
                color: Color(0xFFC74B4E), fontSize: 12)),
              const Icon(Icons.chevron_right, size: 18),
            ]))),
        ),
      ]);
    }),
  );
}

class ExpenseEditorPage extends StatefulWidget {
  final ExpenseEntry? entry;
  final ExpenseEntry? copyFrom;
  const ExpenseEditorPage({super.key, this.entry, this.copyFrom});
  @override
  State<ExpenseEditorPage> createState() => _ExpenseEditorPageState();
}

class _ExpenseEditorPageState extends State<ExpenseEditorPage> {
  late final TextEditingController description = TextEditingController(text: widget.entry?.description ?? widget.copyFrom?.description ?? '');
  late final TextEditingController amount = TextEditingController(text: widget.entry?.amount.toString() ?? widget.copyFrom?.amount.toString() ?? '');
  late final TextEditingController note = TextEditingController(text: widget.entry?.note ?? widget.copyFrom?.note ?? '');
  final reason = TextEditingController();
  late DateTime when = widget.entry?.date ?? DateTime.now();
  late String method = widget.entry?.method ?? widget.copyFrom?.method ?? 'Tunai';
  int? categoryId;
  bool saving = false;
  late Future<List<ExpenseCategory>> categoriesFuture;
  @override
  void initState() {
    super.initState();
    categoryId = widget.entry?.categoryId ?? widget.copyFrom?.categoryId;
    reloadCategories();
  }
  void reloadCategories() => categoriesFuture = ExpensesService.categories(showArchived: true);
  @override
  void dispose() {
    description.dispose(); amount.dispose(); note.dispose(); reason.dispose(); super.dispose();
  }
  Future<void> chooseDate() async {
    final date = await showDatePicker(context: context, initialDate: when,
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 366)));
    if (date == null || !mounted) return;
    setState(() => when = DateTime(date.year, date.month, date.day, when.hour, when.minute));
  }
  Future<void> chooseTime() async {
    final time = await showTimePicker(context: context,
      initialTime: TimeOfDay.fromDateTime(when));
    if (time == null || !mounted) return;
    setState(() => when = DateTime(when.year, when.month, when.day, time.hour, time.minute));
  }
  Future<void> addCategory() async {
    final value = await _askText(context, title: 'Tambah Kategori', hint: 'Contoh: Belanja Sparepart');
    if (value == null) return;
    try {
      final id = await ExpensesService.addCategory(value);
      if (!mounted) return;
      setState(() { categoryId = id; reloadCategories(); });
    } catch (e) { if (mounted) notify(context, '$e'); }
  }
  Future<void> save() async {
    final n = nonNegative(amount.text);
    if (n == null || n <= 0 || description.text.trim().isEmpty) {
      notify(context, 'Masukkan keterangan dan nominal yang valid'); return;
    }
    if (widget.entry != null && reason.text.trim().length < 4) {
      notify(context, 'Tulis alasan perubahan minimal 4 karakter'); return;
    }
    setState(() => saving = true);
    try {
      if (widget.entry == null) {
        await ExpensesService.create(description: description.text, amount: n,
          date: when, categoryId: categoryId, method: method, note: note.text);
      } else {
        await ExpensesService.edit(widget.entry!.id, description: description.text,
          amount: n, date: when, categoryId: categoryId,
          method: method, note: note.text, reason: reason.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) notify(context, '$e'); }
    finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.entry == null ? 'Catat Pengeluaran' : 'Edit Pengeluaran')),
    body: FutureBuilder<List<ExpenseCategory>>(future: categoriesFuture, builder: (ctx, snap) {
      if (snap.hasError) return Center(child: Text('Gagal memuat kategori: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final cats = snap.data!;
      if (categoryId != null && !cats.any((v) => v.id == categoryId)) categoryId = null;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 34), children: [
        TextField(controller: description, maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nama pengeluaran *',
            prefixIcon: Icon(Icons.edit_note))),
        const SizedBox(height: 11),
        TextField(controller: amount, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Nominal (Rp) *',
            prefixIcon: Icon(Icons.payments_outlined))),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(key: ValueKey('expense-category-$categoryId'), isExpanded: true,
            initialValue: categoryId,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [const DropdownMenuItem<int>(value: null, child: Text('Lainnya (default)')),
              ...cats.where((c) => !c.archived || c.id == categoryId).map((c) =>
                DropdownMenuItem<int>(value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis)))],
            onChanged: (v) => setState(() => categoryId = v))),
          IconButton(tooltip: 'Tambah kategori', onPressed: addCategory,
            icon: const Icon(Icons.add_circle_outline)),
        ]),
        const SizedBox(height: 11),
        DropdownButtonFormField<String>(initialValue: method,
          decoration: const InputDecoration(labelText: 'Metode pembayaran'),
          items: ExpensesService.methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) { if (v != null) setState(() => method = v); }),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: chooseDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(dateLabel(when.toIso8601String())))),
          const SizedBox(width: 9),
          Expanded(child: OutlinedButton.icon(onPressed: chooseTime,
            icon: const Icon(Icons.schedule),
            label: Text(timeLabel(when.toIso8601String())))),
        ]),
        const SizedBox(height: 13),
        TextField(controller: note, maxLines: 3, maxLength: 500,
          decoration: const InputDecoration(labelText: 'Catatan tambahan (opsional)')),
        if (widget.entry != null) ...[
          const SizedBox(height: 9),
          TextField(controller: reason, maxLength: 160,
            decoration: const InputDecoration(labelText: 'Alasan koreksi *',
              hintText: 'Contoh: Salah memilih tanggal transaksi')),
        ],
        const SizedBox(height: 13),
        FilledButton.icon(onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Menyimpan...' : 'Simpan Pengeluaran')),
        const SizedBox(height: 10),
        const Text('Perubahan nominal akan mengubah saldo kas dan laporan. '
          'Metode pembayaran bersifat catatan dan tidak otomatis memindahkan dana.',
          style: TextStyle(fontSize: 11)),
      ]);
    }),
  );
}

class ExpenseDetailPage extends StatefulWidget {
  final int id;
  const ExpenseDetailPage({super.key, required this.id});
  @override
  State<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}
class _ExpenseDetailPageState extends State<ExpenseDetailPage> {
  late Future<ExpenseEntry?> entry;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => entry = ExpensesService.find(widget.id));
  Future<void> edit(ExpenseEntry e) async {
    final updated = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => ExpenseEditorPage(entry: e)));
    if (updated == true && mounted) refresh();
  }
  Future<void> duplicate(ExpenseEntry e) async {
    final success = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => ExpenseEditorPage(copyFrom: e)));
    if (success == true && mounted) notify(context, 'Pengeluaran baru tersimpan');
  }
  Future<void> delete(ExpenseEntry e) async {
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus transaksi ini?'),
      content: Text('Pengeluaran ${rupiah(e.amount)} akan dihapus dari kas dan laporan. '
        'Catatan audit perubahan tetap tersimpan.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan'))],
    ));
    if (accepted != true || !mounted) return;
    final reason = await _askText(context, title: 'Alasan menghapus',
      hint: 'Contoh: Transaksi tercatat dua kali');
    if (reason == null) return;
    try {
      await ExpensesService.delete(e.id, reason: reason);
      if (mounted) Navigator.pop(context, true);
    } catch (err) { if (mounted) notify(context, '$err'); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail Pengeluaran')),
    body: FutureBuilder<ExpenseEntry?>(future: entry, builder: (ctx, snap) {
      if (snap.hasError) return Center(child: Text('Gagal memuat: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final e = snap.data;
      if (e == null) return const Center(child: Text('Pengeluaran tidak ditemukan'));
      final details = <String, String>{
        'Kategori': e.category, 'Nominal': rupiah(e.amount),
        'Tanggal': dateLabel(e.date.toIso8601String()),
        'Waktu': timeLabel(e.date.toIso8601String()),
        'Metode': e.method, 'Catatan': e.note.isEmpty ? '—' : e.note,
      };
      return ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.description, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 15),
            for (final x in details.entries) Padding(padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 100, child: Text(x.key,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                Expanded(child: Text(x.value, style: const TextStyle(fontWeight: FontWeight.w700))),
              ])),
          ]))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => edit(e),
          icon: const Icon(Icons.edit_outlined), label: const Text('Edit Detail & Waktu')),
        OutlinedButton.icon(onPressed: () => Clipboard.setData(ClipboardData(
          text: '${e.description} • ${rupiah(e.amount)} • ${e.category} • '
            '${dateLabel(e.date.toIso8601String())} ${timeLabel(e.date.toIso8601String())}'))
          .then((_) { if (mounted) notify(context, 'Detail disalin'); }),
          icon: const Icon(Icons.copy), label: const Text('Salin Detail')),
        OutlinedButton.icon(onPressed: () => duplicate(e),
          icon: const Icon(Icons.copy_all_outlined), label: const Text('Catat Transaksi Baru')),
        TextButton.icon(onPressed: () => delete(e),
          icon: const Icon(Icons.delete_outline), label: const Text('Hapus (dengan alasan)')),
        const SizedBox(height: 20),
        Text('Riwayat koreksi', style: Theme.of(context).textTheme.titleMedium),
        FutureBuilder<List<Map<String, Object?>>>(future: ExpensesService.audit(e.id), builder: (context, a) {
          if (!a.hasData) return const LinearProgressIndicator();
          return Column(children: [for (final log in a.data!) Card(
            child: ListTile(title: Text('${log['action']} • ${log['reason']}'),
              subtitle: Text('${log['occurred_at']}\n'
                '${rupiah((log['old_amount'] as num).toInt())} → '
                '${rupiah((log['new_amount'] as num).toInt())}',
                style: const TextStyle(fontSize: 11))))]);
        }),
      ]);
    }),
  );
}

class ExpenseCategoriesPage extends StatefulWidget {
  const ExpenseCategoriesPage({super.key});
  @override
  State<ExpenseCategoriesPage> createState() => _ExpenseCategoriesPageState();
}
class _ExpenseCategoriesPageState extends State<ExpenseCategoriesPage> {
  late Future<List<ExpenseCategory>> loader;
  @override
  void initState() { super.initState(); reload(); }
  void reload() => setState(() => loader = ExpensesService.categories(showArchived: true));
  Future<void> create() async {
    final name = await _askText(context, title: 'Tambah kategori pengeluaran', hint: 'Nama kategori');
    if (name == null) return;
    try { await ExpensesService.addCategory(name); if (mounted) reload(); }
    catch (e) { if (mounted) notify(context, '$e'); }
  }
  Future<void> rename(ExpenseCategory cat) async {
    final value = await _askText(context, title: 'Ganti nama kategori',
      hint: 'Nama baru untuk ${cat.name}');
    if (value == null) return;
    try { await ExpensesService.renameCategory(cat.id, value); if (mounted) reload(); }
    catch (e) { if (mounted) notify(context, '$e'); }
  }
  Future<void> toggle(ExpenseCategory cat) async {
    try {
      await ExpensesService.archiveCategory(cat.id, archived: !cat.archived);
      if (mounted) reload();
    } catch (e) { if (mounted) notify(context, '$e'); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kategori Pengeluaran'), actions: [
      IconButton(onPressed: create, icon: const Icon(Icons.add_circle_outline)),
    ]),
    body: FutureBuilder<List<ExpenseCategory>>(future: loader, builder: (ctx, snap) {
      if (snap.hasError) return Center(child: Text('${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Kategori lama tetap ditampilkan dalam riwayat. Arsip hanya '
          'menyembunyikan kategori dari transaksi baru.'),
        const SizedBox(height: 14),
        for (final cat in snap.data!) Card(child: ListTile(
          leading: Icon(cat.archived ? Icons.archive_outlined : Icons.category_outlined),
          title: Text(cat.name), subtitle: Text(cat.archived ? 'Diarsipkan' : 'Aktif'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Edit nama kategori',
              onPressed: cat.name.toLowerCase() == 'lainnya' ? null : () => rename(cat),
              icon: const Icon(Icons.edit_outlined, size: 19)),
            IconButton(tooltip: cat.archived ? 'Aktifkan' : 'Arsipkan',
              onPressed: cat.name.toLowerCase() == 'lainnya' ? null : () => toggle(cat),
              icon: Icon(cat.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 19)),
          ]),
        )),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: create, icon: const Icon(Icons.add),
          label: const Text('Tambah Kategori')),
      ]);
    }),
  );
}


class ExpenseAuditPage extends StatelessWidget {
  const ExpenseAuditPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat Koreksi Pengeluaran')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: ExpensesService.auditAll(), builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Text('Gagal: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.isEmpty) return const Center(child: Text('Belum ada riwayat koreksi.'));
        return ListView(padding: const EdgeInsets.all(16), children: [
          for (final row in snap.data!) Card(child: ListTile(
            title: Text('Transaksi #${row['expense_id']} • ${row['action']}'),
            subtitle: Text('${row['reason']}
${row['occurred_at']}
'
              '${row['snapshot']}', maxLines: 5, overflow: TextOverflow.ellipsis),
            trailing: Text('${rupiah((row['old_amount'] as num).toInt())}
→ '
              '${rupiah((row['new_amount'] as num).toInt())}',
              textAlign: TextAlign.end, style: const TextStyle(fontSize: 10)),
          )),
        ]);
      }),
  );
}

Future<String?> _askText(BuildContext context, {required String title, required String hint}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title),
    content: TextField(controller: ctrl, autofocus: true, maxLength: 160,
      maxLines: 2, decoration: InputDecoration(hintText: hint)),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
      FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
        child: const Text('Lanjut'))],
  ));
  ctrl.dispose();
  return result?.trim().isEmpty == true ? null : result;
}
