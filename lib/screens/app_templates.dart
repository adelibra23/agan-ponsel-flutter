import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/format.dart';
import '../widgets/kit.dart';

class AppTemplatesScreen extends StatefulWidget {
  final String currentStyle;
  final ValueChanged<String> onStyleChanged;
  const AppTemplatesScreen({super.key, required this.currentStyle,
    required this.onStyleChanged});
  @override
  State<AppTemplatesScreen> createState() => _AppTemplatesScreenState();
}

class _AppTemplatesScreenState extends State<AppTemplatesScreen> {
  late String selected = widget.currentStyle;
  String message = 'Ramah';
  String selectedFont = 'Roboto';
  @override
  void initState() { super.initState(); loadMessage(); }
  Future<void> loadMessage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      message = prefs.getString('reminder_message_template') ?? 'Ramah';
      selectedFont = prefs.getString('app_font_family') ?? 'Roboto';
      if (!appFontChoices.containsKey(selectedFont)) selectedFont = 'Roboto';
    });
  }

  Future<void> change(String style) async {
    setState(() => selected = style);
    widget.onStyleChanged(style);
    notify(context, 'Template $style diterapkan');
  }

  Future<void> changeFont(String font) async {
    if (!appFontChoices.containsKey(font)) return;
    await (await SharedPreferences.getInstance()).setString('app_font_family', font);
    aganFontFamily.value = font;
    if (mounted) {
      setState(() => selectedFont = font);
      notify(context, 'Tipografi ${appFontChoices[font]} diterapkan');
    }
  }

  Future<void> changeMessage(String style) async {
    await (await SharedPreferences.getInstance()).setString('reminder_message_template', style);
    if (mounted) setState(() => message = style);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Template AGAN PONSEL')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 30), children: [
      const PageIntro('Gaya khas toko', 'Pilih palet warna untuk header, tombol dan navigasi'),
      for (final name in appTemplates) ...[
        _ThemeOption(name: name, selected: selected == name, onTap: () => change(name)),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 18),
      const SectionTitle('Jenis Tipografi',
        subtitle: 'Pilih font yang nyaman dibaca. Berlaku untuk seluruh aplikasi.'),
      Surface(child: Column(children: [
        for (final item in appFontChoices.entries)
          RadioListTile<String>(
            title: Text(item.value, style: TextStyle(fontFamily: item.key,
              fontWeight: FontWeight.w700)),
            subtitle: Text('AGAN PONSEL · Rp125.000',
              style: TextStyle(fontFamily: item.key)),
            value: item.key, groupValue: selectedFont,
            onChanged: (v) { if (v != null) changeFont(v); }),
      ])),
      const SizedBox(height: 20),
      const SectionTitle('Template pesan pengingat',
        subtitle: 'Pesan bisa disalin dari Detail Piutang. Tidak terkirim otomatis.'),
      Surface(child: Column(children: [
        for (final style in const ['Ramah', 'Formal', 'Singkat'])
          RadioListTile<String>(title: Text(style), value: style,
            groupValue: message, onChanged: (v) { if (v != null) changeMessage(v); }),
      ])),
      const SizedBox(height: 18),
      Surface(child: Row(children: [
        Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        const Expanded(child: Text('Warna, font dan pesan disimpan di Android dan ikut dalam backup.',
          style: TextStyle(fontSize: 12))),
      ])),
    ]),
  );
}

class _ThemeOption extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.name, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(22),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: selected ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outlineVariant, width: selected ? 2 : 1),
        borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Expanded(child: Container(height: 80,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            gradient: LinearGradient(colors: templateGradient(name))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AGAN PONSEL', style: TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]))),
        SizedBox(width: 56, child: Icon(selected ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
          color: selected ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
  );
}
