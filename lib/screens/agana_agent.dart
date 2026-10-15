import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent/agent_intents.dart';
import '../agent/agent_service.dart';
import '../core/theme.dart';
import '../widgets/identity.dart';
import '../widgets/kit.dart';
import 'cash_screen.dart';
import 'inventory.dart';
import 'others.dart';
import 'receivables.dart';
import 'services.dart';
import 'store_notes.dart';

class AganaAgentScreen extends StatefulWidget {
  const AganaAgentScreen({super.key});
  @override
  State<AganaAgentScreen> createState() => _AganaAgentScreenState();
}

class _AgentMessage {
  final String text;
  final bool mine;
  AgentIntent? proposal;
  String? destination;
  bool resolved = false;
  _AgentMessage(this.text, {this.mine = false, this.proposal, this.destination});
}

class _AganaAgentScreenState extends State<AganaAgentScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;
  final messages = <_AgentMessage>[
    _AgentMessage('Halo! Saya AGANA. Saya bisa memeriksa data toko dan membantu membuat catatan. '
      'Mulai dari tombol contoh atau ketik perintah. Saya akan meminta persetujuan sebelum menyimpan perubahan.'),
  ];
  static const suggestions = [
    'Pengingat jatuh tempo', 'Cek stok menipis', 'Laporan hari ini',
    'Cek service', 'Tambah pelanggan', 'Catat pengeluaran',
  ];

  @override
  void dispose() { input.dispose(); scroll.dispose(); super.dispose(); }

  void scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.animateTo(scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 310), curve: Curves.easeOutCubic);
    });
  }

  Future<void> send([String? example]) async {
    if (busy) return;
    final text = (example ?? input.text).trim();
    if (text.isEmpty) return;
    if (text.length > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perintah maksimal 300 karakter')));
      return;
    }
    input.clear();
    FocusScope.of(context).unfocus();
    setState(() { messages.add(_AgentMessage(text, mine: true)); busy = true; });
    scrollBottom();
    try {
      final result = await AgentService.ask(text);
      if (!mounted) return;
      setState(() => messages.add(_AgentMessage(result.message,
        proposal: result.proposal, destination: result.destination)));
    } catch (e) {
      if (!mounted) return;
      setState(() => messages.add(_AgentMessage('Gagal membaca data toko. Periksa database atau coba lagi. ($e)')));
    } finally {
      if (mounted) setState(() => busy = false);
      scrollBottom();
    }
  }

  Future<void> showActivity() async {
    try {
      final entries = await AgentService.activity();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, showDragHandle: true,
        builder: (context) => SafeArea(child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: Column(children: [
            const ListTile(title: Text('Riwayat Tindakan AGANA',
              style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Hanya tindakan yang disimpan, tidak termasuk isi percakapan')),
            Expanded(child: entries.isEmpty
              ? const Center(child: Text('Belum ada tindakan yang disimpan'))
              : ListView.builder(itemCount: entries.length, itemBuilder: (ctx, i) {
                  final entry = entries[i];
                  final action = '${entry['action']}'.replaceAll('_', ' ');
                  return ListTile(
                    leading: const Icon(Icons.verified_user_rounded),
                    title: Text(action), subtitle: Text('${entry['created_at']}'),
                  );
                })),
          ]),
        )),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Riwayat tidak dapat dibuka: $e')));
    }
  }

  Future<void> approve(_AgentMessage message) async {
    if (busy || message.resolved || message.proposal == null) return;
    final draft = message.proposal!;
    setState(() => busy = true);
    try {
      final response = await AgentService.confirm(draft);
      if (!mounted) return;
      setState(() {
        message.resolved = true;
        messages.add(_AgentMessage('✓ $response'));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => messages.add(_AgentMessage('Tidak disimpan: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
      scrollBottom();
    }
  }

  void openDestination(String key) {
    final Widget? target;
    switch (key) {
      case 'debt': target = const ReceivablesScreen(); break;
      case 'inventory': target = const InventoryScreen(); break;
      case 'service': target = const ServicesScreen(); break;
      case 'customers': target = const CustomersScreen(); break;
      case 'expenses': target = const ExpensesScreen(); break;
      case 'notes': target = const StoreNotesScreen(); break;
      case 'sales': target = const SalesHistoryScreen(); break;
      case 'cash': target = const CashScreen(); break;
      case 'reports': target = const ReportsScreen(); break;
      default: target = null;
    }
    if (target != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => target!));
    }
  }

  String destinationLabel(String key) {
    switch (key) {
      case 'debt': return 'Buka Piutang';
      case 'inventory': return 'Buka Produk';
      case 'service': return 'Buka Service';
      case 'customers': return 'Buka Pelanggan';
      case 'expenses': return 'Buka Pengeluaran';
      case 'notes': return 'Buka Tugas';
      case 'sales': return 'Buka Riwayat';
      case 'cash': return 'Buka Buku Kas';
      case 'reports': return 'Buka Laporan';
      default: return 'Buka Halaman';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          const AnimatedBrandMark(size: 43),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AGANA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)),
            Text('Asisten pintar toko • lokal', style: TextStyle(fontSize: 11)),
          ])),
        ]),
        actions: [
          IconButton(tooltip: 'Riwayat tindakan', onPressed: showActivity,
            icon: const Icon(Icons.history_rounded)),
          IconButton(tooltip: 'Bantuan perintah', onPressed: () => send('bantuan'),
            icon: const Icon(Icons.help_outline_rounded)),
        ],
      ),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              color: palette.primary.withValues(alpha: .075)),
            child: Row(children: [
              Icon(Icons.shield_outlined, color: palette.primary, size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text('Data dibaca dari SQLite di HP. Perubahan memerlukan persetujuanmu.',
                style: TextStyle(color: palette.onSurfaceVariant, fontSize: 11.5))),
            ]))),
        Expanded(child: ListView.builder(
          controller: scroll, padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          itemCount: messages.length + (busy ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == messages.length) {
              return const Align(alignment: Alignment.centerLeft, child: Padding(
                padding: EdgeInsets.all(12), child: Text('AGANA sedang memeriksa data…')));
            }
            final message = messages[i];
            return _bubble(context, message);
          },
        )),
        SizedBox(height: 46, child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [for (final sample in suggestions) Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ActionChip(label: Text(sample, style: const TextStyle(fontSize: 11)),
              onPressed: busy ? null : () {
                if (sample == 'Tambah pelanggan') {
                  send('tambah pelanggan');
                } else if (sample == 'Catat pengeluaran') {
                  send('catat pengeluaran');
                } else if (sample == 'Cek service') {
                  send('cek service');
                } else { send(sample); }
              }),
          )]),
        ),
        Container(
          decoration: BoxDecoration(color: palette.surface,
            border: Border(top: BorderSide(color: palette.outlineVariant.withValues(alpha: .35)))),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(children: [
            Expanded(child: TextField(
              controller: input,
              minLines: 1, maxLines: 4, maxLength: 300,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => send(),
              decoration: InputDecoration(
                hintText: 'Contoh: cek tagihan Budi',
                counterText: '', filled: true,
                prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 19),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Kirim perintah', onPressed: busy ? null : () { HapticFeedback.selectionClick(); send(); },
              icon: const Icon(Icons.arrow_upward_rounded)),
          ]),
        ),
      ])),
    );
  }

  Widget _bubble(BuildContext context, _AgentMessage msg) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: msg.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
          decoration: BoxDecoration(
            color: msg.mine ? scheme.primary : scheme.surface,
            border: msg.mine ? null : Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(msg.mine ? 18 : 5),
              bottomRight: Radius.circular(msg.mine ? 5 : 18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!msg.mine) ...[
              Text('AGANA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                color: scheme.primary)), const SizedBox(height: 6),
            ],
            SelectableText(msg.text, style: TextStyle(height: 1.48, fontSize: 13,
              color: msg.mine ? scheme.onPrimary : scheme.onSurface)),
            if (msg.proposal != null) ...[
              const SizedBox(height: 13),
              if (msg.resolved) const Row(children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                SizedBox(width: 6), Text('Tindakan sudah diproses'),
              ]) else Wrap(spacing: 8, children: [
                FilledButton.icon(onPressed: busy ? null : () => approve(msg),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Setujui & Simpan')),
                OutlinedButton(onPressed: busy ? null : () => setState(() => msg.resolved = true),
                  child: const Text('Batal')),
              ]),
            ],
            if (msg.destination != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(onPressed: () => openDestination(msg.destination!),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text(destinationLabel(msg.destination!))),
            ],
          ]),
        ),
      ),
    );
  }
}
