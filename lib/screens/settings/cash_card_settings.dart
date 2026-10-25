import 'package:flutter/material.dart';

import '../../widgets/premium_cash_card.dart';

/// Card appearance only. No banking connection, no external payments.
class CashCardSettingsScreen extends StatefulWidget {
  const CashCardSettingsScreen({super.key});
  @override
  State<CashCardSettingsScreen> createState() => _CashCardSettingsScreenState();
}

class _CashCardSettingsScreenState extends State<CashCardSettingsScreen> {
  late Future<CashCardAppearance> appearance;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    appearance = CashCardSettings.read();
  }

  Future<void> update(Future<void> Function() change) async {
    if (updating) return;
    setState(() => updating = true);
    try {
      await change();
      if (mounted) setState(() => appearance = CashCardSettings.read());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan tampilan kartu: $error')));
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pilihan Kartu Premium')),
    body: FutureBuilder<CashCardAppearance>(future: appearance, builder: (ctx, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final value = snap.data!;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 15, 16, 32), children: [
        Text('Desain Kartu Saldo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('Pilih warna dan gaya kartu untuk Beranda serta Dompet Kas Toko.',
          style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 17),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 1.48,
            crossAxisSpacing: 11, mainAxisSpacing: 11),
          itemCount: cashCardPresets.length,
          itemBuilder: (ctx, i) {
            final preset = cashCardPresets[i];
            final selected = value.style == preset.id;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: updating ? null : () => update(
                () => CashCardSettings.setStyle(preset.id)),
              child: Semantics(selected: selected, label: 'Kartu ${preset.title}',
                child: CashCardThemePreview(preset: preset, selected: selected)));
          },
        ),
        const SizedBox(height: 19),
        Text('Preferensi Tampilan', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(child: Column(children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.compress_rounded),
            title: const Text('Kartu Ringkas'),
            subtitle: const Text('Kurangi tinggi kartu agar Beranda lebih lega'),
            value: value.compact,
            onChanged: updating ? null : (v) => update(
              () => CashCardSettings.setCompact(v))),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Tampilkan Saldo'),
            subtitle: const Text('Saldo disembunyikan secara bawaan demi privasi'),
            value: value.visible,
            onChanged: updating ? null : (v) => update(
              () => CashCardSettings.setVisible(v))),
        ])),
        const SizedBox(height: 12),
        Text('Pilihan desain tersedia tanpa biaya dan tidak mengubah data kas. '
          'Warna serta ukuran kartu ikut dicadangkan; pilihan tampil/samarkan saldo '
          'tetap tersimpan khusus di perangkat.',
          style: Theme.of(context).textTheme.bodySmall),
      ]);
    }),
  );
}
