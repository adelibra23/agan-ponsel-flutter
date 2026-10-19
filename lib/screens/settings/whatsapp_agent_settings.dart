import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../services/whatsapp_agent_api.dart';
import '../../widgets/kit.dart';

class WhatsappAgentSettingsScreen extends StatefulWidget {
  const WhatsappAgentSettingsScreen({super.key});
  @override
  State<WhatsappAgentSettingsScreen> createState() => _WhatsappAgentSettingsScreenState();
}

class _WhatsappAgentSettingsScreenState extends State<WhatsappAgentSettingsScreen> {
  final url = TextEditingController();
  final token = TextEditingController();
  bool busy = false;
  bool savedToken = false;
  bool showToken = false;
  Map<String, dynamic>? current;
  String? error;

  @override
  void initState() { super.initState(); initialize(); }
  @override
  void dispose() { url.dispose(); token.dispose(); super.dispose(); }

  Future<void> initialize() async {
    try {
      final savedUrl = await WhatsappAgentApi.savedUrl();
      final hasToken = await WhatsappAgentApi.hasAdminToken();
      if (!mounted) return;
      setState(() { url.text = savedUrl; savedToken = hasToken; });
      if (savedUrl.isNotEmpty && hasToken) await refresh();
    } catch (e) { if (mounted) setState(() => error = '$e'); }
  }

  Future<void> _execute(Future<void> Function() operation) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try { await operation(); }
    catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> refresh() => _execute(() async {
    final data = await WhatsappAgentApi.status();
    if (mounted) setState(() => current = data);
  });

  Future<void> saveAndTest() => _execute(() async {
    await WhatsappAgentApi.save(url.text, token.text.isEmpty ? null : token.text);
    final data = await WhatsappAgentApi.status();
    if (!mounted) return;
    setState(() { current = data; savedToken = true; token.clear(); showToken = false; });
    notify(context, 'Server WhatsApp terhubung');
  });

  Future<void> changeEnabled(bool enabled) => _execute(() async {
    final data = await WhatsappAgentApi.setEnabled(enabled);
    if (!mounted) return;
    setState(() => current = data);
    notify(context, enabled ? 'Balasan otomatis diaktifkan di server' : 'Balasan otomatis dijeda');
  });

  Future<void> changeHandoff(String id, bool paused) => _execute(() async {
    await WhatsappAgentApi.handoff(id, paused);
    final data = await WhatsappAgentApi.status();
    if (mounted) setState(() => current = data);
  });

  Future<void> disconnect() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Lepaskan koneksi dari HP?'),
      content: const Text('Ini menghapus alamat dan token admin dari HP. Agen di server tetap berjalan sampai dimatikan melalui server atau pengaturan ini.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lepaskan')),
      ],
    ));
    if (yes != true) return;
    await _execute(() async {
      await WhatsappAgentApi.disconnect();
      if (mounted) setState(() { current = null; savedToken = false; url.clear(); token.clear(); });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = current;
    final enabled = status?['enabled'] == true;
    final threads = status?['threads'] is List ? status!['threads'] as List : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('AGANA • WhatsApp Agent'), actions: [
        IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Perbarui status'),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF075945), Color(0xFF0EA789)]),
          borderRadius: BorderRadius.circular(24)),
          child: const Row(children: [
            Icon(Icons.smart_toy_rounded, color: Colors.white, size: 42),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AGANA Customer Assistant', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 18)),
              SizedBox(height: 5),
              Text('Balas pertanyaan pelanggan dengan konteks percakapan di WhatsApp Business.',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            ])),
          ])),
        const SizedBox(height: 16),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Sambungan server WhatsApp'),
          const Text('Diperlukan WhatsApp Business Platform, server webhook HTTPS, dan token admin dari server. WhatsApp pribadi tidak bisa disadap otomatis.',
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          TextField(controller: url, enabled: !busy, keyboardType: TextInputType.url,
            autocorrect: false, decoration: inputDecoration('URL server HTTPS',
              hint: 'https://wa.tokokamu.id', icon: Icons.link_rounded)),
          const SizedBox(height: 11),
          TextField(controller: token, obscureText: !showToken, enabled: !busy,
            autocorrect: false, enableSuggestions: false,
            decoration: inputDecoration(savedToken ? 'Token admin (kosong = gunakan tersimpan)' : 'Token admin server',
              icon: Icons.key_rounded).copyWith(suffixIcon: IconButton(
                onPressed: () => setState(() => showToken = !showToken),
                icon: Icon(showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: busy ? null : saveAndTest, icon: const Icon(Icons.cloud_done_outlined),
            label: const Text('Simpan & Uji Server'))),
          if (savedToken) TextButton.icon(onPressed: busy ? null : disconnect,
            icon: const Icon(Icons.link_off_rounded), label: const Text('Lepaskan Koneksi')),
        ])),
        const SizedBox(height: 12),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Balasan otomatis'),
          Row(children: [
            Icon(status != null ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
              color: status != null ? const Color(0xFF079B79) : scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(status == null ? 'Server belum tersambung' :
                enabled ? 'Agen sedang aktif' : 'Agen dijeda',
                style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          if (status != null) ...[
            const SizedBox(height: 10),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktifkan agen WhatsApp'),
              subtitle: const Text('Membalas pesan pelanggan baru secara otomatis'),
              value: enabled, onChanged: busy ? null : changeEnabled),
            Text('AI: ${status['ai_ready'] == true ? 'Siap' : 'Belum dikonfigurasi'} • '
              'Nomor Business: ${status['phone_ready'] == true ? 'Siap' : 'Belum lengkap'}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
          if (busy) const Padding(padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(minHeight: 3)),
        ])),
        if (error != null) ...[
          const SizedBox(height: 10),
          Surface(child: Row(children: [const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8), Expanded(child: Text(error!,
              style: const TextStyle(fontSize: 12)))])),
        ],
        if (status != null) ...[
          const SizedBox(height: 18),
          const SectionTitle('Percakapan terbaru', subtitle: 'Hanya empat digit terakhir; isi chat tetap di server.'),
          if (threads.isEmpty) const Surface(child: Text('Belum ada percakapan masuk.')),
          for (final entry in threads) if (entry is Map) ...[
            Surface(child: ListTile(contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline_rounded)),
              title: Text('Pelanggan ••••${entry['last4'] ?? '----'}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(entry['paused'] == true ? 'Ditangani admin' : 'Dikelola AGANA'),
              trailing: TextButton(onPressed: busy ? null : () => changeHandoff(
                '${entry['id']}', entry['paused'] != true),
                child: Text(entry['paused'] == true ? 'Aktifkan AI' : 'Alihkan admin')),
            )),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 14),
        Surface(child: Text('Penting: AI WhatsApp menggunakan API key yang dikonfigurasi di HOSTING, terpisah dari AGANA pada HP. Pesan pelanggan diproses oleh penyedia AI pilihan. Perlu pemberitahuan privasi, persetujuan yang sesuai, dan server yang tetap berjalan. Saat pelanggan meminta admin, otomatisasi dihentikan untuk percakapan itu.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
        const SizedBox(height: 22),
      ]),
    );
  }
}
