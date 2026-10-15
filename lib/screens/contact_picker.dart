import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../core/theme.dart';
import '../widgets/kit.dart';

class ContactChoice {
  final String name;
  final String number;
  const ContactChoice(this.name, this.number);
}

/// Contacts are accessed only following an explicit tap and Android permission.
/// No bulk import or background synchronization is performed.
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});
  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  bool loading = true;
  bool denied = false;
  String query = '';
  List<Contact> contacts = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; denied = false; });
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) setState(() { denied = true; loading = false; });
        return;
      }
      final entries = await FlutterContacts.getContacts(withProperties: true);
      entries.removeWhere((c) => c.phones.isEmpty);
      entries.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      if (mounted) setState(() { contacts = entries; loading = false; });
    } catch (_) { if (mounted) setState(() { denied = true; loading = false; }); }
  }

  Future<void> choose(Contact c) async {
    if (c.phones.isEmpty) return;
    String? picked;
    if (c.phones.length == 1) {
      picked = c.phones.first.number;
    } else {
      picked = await showModalBottomSheet<String>(context: context, showDragHandle: true,
        builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Pilih nomor ${c.displayName}',
            style: Theme.of(ctx).textTheme.titleMedium)),
          for (final number in c.phones)
            ListTile(leading: const Icon(Icons.phone_outlined), title: Text(number.number),
              onTap: () => Navigator.pop(ctx, number.number)),
        ])));
    }
    if (!mounted || picked == null || picked.trim().isEmpty) return;
    Navigator.of(context).pop(ContactChoice(c.displayName, picked.trim()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pilih Kontak Pelanggan')),
    body: loading ? const ScreenLoading()
      : denied ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.contacts_outlined, size: 42, color: brandBlue),
            const SizedBox(height: 12),
            const Text('Izin membaca kontak belum diberikan', textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text('Izinkan akses kontak melalui dialog Android. Jika ditolak permanen, aktifkan di Pengaturan Android > Aplikasi > AGAN PONSEL > Izin.',
              textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi')),
          ])))
      : Column(children: [
          Padding(padding: const EdgeInsets.all(14), child: SearchBox(
            hint: 'Cari nama atau nomor di kontak...', onChanged: (v) => setState(() => query = v))),
          Expanded(child: Builder(builder: (context) {
            final filtered = contacts.where((c) {
              final needle = query.toLowerCase();
              return c.displayName.toLowerCase().contains(needle) ||
                c.phones.any((p) => p.number.toLowerCase().contains(needle));
            }).take(300).toList();
            if (filtered.isEmpty) return const EmptyView(icon: Icons.person_search_rounded,
              title: 'Kontak tidak ditemukan', subtitle: 'Coba nama atau nomor lain.');
            return ListView.builder(itemCount: filtered.length, itemBuilder: (ctx, i) {
              final c = filtered[i];
              return ListTile(
                leading: CircleAvatar(backgroundColor: brandBlue.withValues(alpha: .10),
                  child: const Icon(Icons.person_outline, color: brandBlue)),
                title: Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(c.phones.first.number),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => choose(c));
            });
          })),
        ]),
  );
}
