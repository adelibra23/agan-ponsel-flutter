import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/ai_gateway.dart';
import '../../core/format.dart';
import '../../widgets/kit.dart';

/// Owner can review the stored key after tapping the eye icon.
/// The text is obscured by default and never logged or exported.
class AganaAiSettingsScreen extends StatefulWidget {
  const AganaAiSettingsScreen({super.key});
  @override
  State<AganaAiSettingsScreen> createState() => _AganaAiSettingsScreenState();
}

class _AganaAiSettingsScreenState extends State<AganaAiSettingsScreen> {
  final keyController = TextEditingController();
  final modelController = TextEditingController();
  String provider = 'openrouter';
  bool enabled = false;
  bool shortAnswers = true;
  bool keySaved = false;
  bool busy = true;
  bool hideKey = true;
  String? testResult;

  @override
  void initState() { super.initState(); initialize(); }
  @override
  void dispose() { keyController.dispose(); modelController.dispose(); super.dispose(); }

  Future<void> initialize() async {
    try {
      final config = await AiGateway.load();
      final existingKey = await AiGateway.readStoredKey(config.provider);
      if (!mounted) return;
      setState(() {
        provider = config.provider;
        modelController.text = config.model;
        keyController.text = existingKey ?? '';
        enabled = config.enabled;
        shortAnswers = config.shortAnswers;
        keySaved = existingKey != null && existingKey.isNotEmpty;
        hideKey = true;
        busy = false;
      });
    } catch (e) {
      if (mounted) { setState(() => busy = false); notify(context, 'Pengaturan AI tidak dapat dibuka: $e'); }
    }
  }

  Future<void> selectProvider(String next) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final chosen = AiProviders.byId(next);
      final existingKey = await AiGateway.readStoredKey(chosen.id);
      final savedModel = await AiGateway.modelForProvider(chosen.id);
      if (!mounted) return;
      setState(() {
        provider = chosen.id;
        modelController.text = savedModel;
        keyController.text = existingKey ?? '';
        keySaved = existingKey != null && existingKey.isNotEmpty;
        hideKey = true;
        testResult = null;
      });
    } catch (e) {
      if (mounted) notify(context, 'Gagal memuat API key: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> saveSettings() async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await AiGateway.save(provider: provider, model: modelController.text,
        enabled: enabled, shortAnswers: shortAnswers,
        newApiKey: keyController.text.isNotEmpty ? keyController.text : null);
      final savedKey = await AiGateway.readStoredKey(provider);
      if (!mounted) return false;
      setState(() {
        keySaved = savedKey != null && savedKey.isNotEmpty;
        keyController.text = savedKey ?? '';
        hideKey = true;
        testResult = null;
      });
      notify(context, 'Pengaturan AGANA disimpan dengan aman');
      return true;
    } catch (e) {
      if (mounted) notify(context, '$e');
      return false;
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> test() async {
    // Persist the draft first; test does not require enabling the assistant.
    final wasSaved = await saveSettings();
    if (!wasSaved || !mounted) return;
    setState(() { busy = true; testResult = null; });
    try {
      final answer = await AiGateway.ask('Jawab tepat dua kata: AGANA SIAP', testConnection: true);
      if (mounted) setState(() => testResult = 'Koneksi berhasil. Balasan model: $answer');
    } catch (e) {
      if (mounted) setState(() => testResult = 'Koneksi gagal: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> delete() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus API key?'),
      content: const Text('Kunci milik penyedia AI yang dipilih akan dihapus dari HP ini. Tidak menghapus key di akun penyedia.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
      ],
    ));
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await AiGateway.deleteKey(provider);
      if (mounted) {
        setState(() { keySaved = false; enabled = false; keyController.clear(); testResult = null; });
        notify(context, 'API key telah dihapus dari perangkat');
      }
    } catch (e) { if (mounted) notify(context, 'Gagal menghapus: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> openProvider() async {
    final url = Uri.parse(AiProviders.byId(provider).keyUrl);
    if (!(await launchUrl(url, mode: LaunchMode.externalApplication)) && mounted) {
      notify(context, 'Browser tidak dapat dibuka');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AGANA • Pengaturan AI')),
      body: busy && modelController.text.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [Color(0xFF0736B1), Color(0xFF0D91F3)])),
            child: const Row(children: [
              Icon(Icons.smart_toy_rounded, color: Colors.white, size: 39),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AGANA AI Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
                SizedBox(height: 5),
                Text('Pilih penyedia, masukkan API key sendiri, lalu uji sambungan.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ])),
          const SizedBox(height: 16),
          Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Penyedia AI'),
            for (final entry in AiProviders.all) RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: entry.id,
              groupValue: provider,
              title: Text(entry.label, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700)),
              subtitle: Text(entry.id == 'openrouter'
                ? 'Router ke model gratis, dengan batas penggunaan'
                : entry.id == 'gemini' ? 'Tersedia kuota gratis pada model yang memenuhi syarat'
                : 'Paket gratis dengan kuota berbeda untuk setiap model',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
              onChanged: busy ? null : (v) { if (v != null) selectProvider(v); },
            ),
            const SizedBox(height: 8),
            TextField(controller: modelController,
              decoration: inputDecoration('Model / ID model', icon: Icons.memory_rounded)),
            const SizedBox(height: 11),
            TextField(controller: keyController, obscureText: hideKey,
              autocorrect: false, enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
              decoration: inputDecoration(keySaved
                  ? 'API key tersimpan (ketuk mata untuk melihat atau ubah)'
                  : 'Tempel API key dari penyedia', icon: Icons.key_rounded).copyWith(
                suffixIcon: IconButton(tooltip: hideKey ? 'Lihat input' : 'Sembunyikan input',
                  onPressed: () => setState(() => hideKey = !hideKey),
                  icon: Icon(hideKey ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
              )),
            const SizedBox(height: 8),
            Row(children: [
              Icon(keySaved ? Icons.verified_user_rounded : Icons.info_outline,
                color: keySaved ? const Color(0xFF1CA581) : scheme.onSurfaceVariant, size: 17),
              const SizedBox(width: 7),
              Expanded(child: Text(keySaved ? 'API key tersimpan, tersedia di kolom (disembunyikan secara default)' : 'Belum ada API key tersimpan',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: busy ? null : openProvider,
              icon: const Icon(Icons.open_in_new), label: const Text('Buat / kelola API key')),
          ])),
          const SizedBox(height: 12),
          Surface(child: Column(children: [
            SwitchListTile(contentPadding: EdgeInsets.zero,
              title: const Text('Aktifkan AI internet', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Perintah toko yang dikenali tetap diproses oleh sistem lokal'),
              value: enabled, onChanged: busy ? null : (v) => setState(() => enabled = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero,
              title: const Text('Jawaban ringkas'),
              subtitle: const Text('Mengurangi penggunaan token'),
              value: shortAnswers, onChanged: busy ? null : (v) => setState(() => shortAnswers = v)),
          ])),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy ? null : () { saveSettings(); },
            icon: const Icon(Icons.save_rounded), label: const Text('Simpan Pengaturan')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: busy ? null : test,
            icon: const Icon(Icons.network_check_rounded), label: const Text('Uji Koneksi AI')),
          if (keySaved) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: busy ? null : delete, icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus API Key')),
          ],
          if (testResult != null) ...[
            const SizedBox(height: 8),
            Surface(child: SelectableText(testResult!, style: TextStyle(color: scheme.onSurface))),
          ],
          const SizedBox(height: 12),
          Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Privasi dan biaya', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Saat AI internet aktif, teks pertanyaan yang kamu kirim diproses penyedia pilihanmu. '
              'Database toko, daftar pelanggan, PIN, dan saldo tidak dikirim otomatis. '
              'Jangan memasukkan data pelanggan atau rahasia dalam pertanyaan jika tidak ingin mengirimkannya ke penyedia. '
              'Kuota gratis dapat berubah, beberapa model berbayar. Biaya ditentukan oleh penyedia dan model yang dipilih.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.45)),
          ])),
          const SizedBox(height: 12),
        ]),
    );
  }
}
