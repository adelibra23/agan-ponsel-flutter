import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pin_security.dart';
import '../../core/theme.dart';
import '../../widgets/kit.dart';

class PinGate extends StatefulWidget {
  final Widget child;
  const PinGate({super.key, required this.child});
  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> with WidgetsBindingObserver {
  bool checking = true;
  bool locked = false;
  DateTime? backgrounded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    final required = await PinSecurity.enabled;
    if (mounted) setState(() { locked = required; checking = false; });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      backgrounded ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final elapsed = backgrounded == null ? Duration.zero : DateTime.now().difference(backgrounded!);
      backgrounded = null;
      if (elapsed >= const Duration(seconds: 20)) lockIfEnabled();
    }
  }

  Future<void> lockIfEnabled() async {
    if (await PinSecurity.enabled && mounted) setState(() => locked = true);
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // Keep the app mounted behind the lock when backgrounded; do not re-open DB.
    return Stack(children: [
      widget.child,
      if (locked) Positioned.fill(child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: PinUnlockScreen(onUnlocked: () => setState(() => locked = false)))),
    ]);
  }
}

class PinUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinUnlockScreen({super.key, required this.onUnlocked});
  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final code = TextEditingController();
  bool busy = false;
  String message = 'Masukkan PIN 6 digit untuk membuka aplikasi';

  @override
  void dispose() { code.dispose(); super.dispose(); }
  Future<void> unlock() async {
    if (busy || !PinSecurity.valid(code.text)) return;
    setState(() => busy = true);
    try {
      final result = await PinSecurity.verify(code.text);
      if (!mounted) return;
      code.clear();
      if (result.accepted) { widget.onUnlocked(); return; }
      HapticFeedback.heavyImpact();
      setState(() => message = result.cooldownSeconds > 0
          ? 'Terlalu banyak percobaan. Tunggu ${result.cooldownSeconds} detik.'
          : 'PIN salah. Silakan coba kembali.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Center(child:
    SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420), child: Column(children: [
        Container(width: 84, height: 84, decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0639BA), brandBlue, brandCyan]),
          borderRadius: BorderRadius.circular(25)),
          child: const Icon(Icons.lock_person_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 25),
        const Text('AGAN PONSEL', style: TextStyle(fontSize: 25,
          fontWeight: FontWeight.w900, letterSpacing: .5)),
        const SizedBox(height: 7),
        const Text('Aplikasi terkunci', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 26),
        TextField(controller: code, autofocus: true, obscureText: true,
          obscuringCharacter: '●', textAlign: TextAlign.center,
          maxLength: PinSecurity.pinLength, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) { if (v.length == PinSecurity.pinLength) unlock(); },
          decoration: inputDecoration('PIN 6 digit', icon: Icons.pin_outlined).copyWith(counterText: '')),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: busy ? null : unlock,
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(busy ? 'Memverifikasi...' : 'Buka Aplikasi')),
        const SizedBox(height: 18),
        const Text('PIN lokal tidak mengenkripsi database maupun backup.\nJangan bagikan PIN dan simpan backup dengan aman.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    )),
  ));
}

class PinSettingsScreen extends StatefulWidget {
  const PinSettingsScreen({super.key});
  @override
  State<PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends State<PinSettingsScreen> {
  final oldPin = TextEditingController();
  final newPin = TextEditingController();
  final confirmPin = TextEditingController();
  bool enabled = false;
  bool busy = false;

  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    final value = await PinSecurity.enabled;
    if (mounted) setState(() => enabled = value);
  }
  @override
  void dispose() { oldPin.dispose(); newPin.dispose(); confirmPin.dispose(); super.dispose(); }

  Future<void> submit({required bool disable}) async {
    if (busy) return;
    if (!disable && (!PinSecurity.valid(newPin.text) || newPin.text != confirmPin.text)) {
      notify(context, 'PIN baru harus 6 digit dan konfirmasi harus sama'); return;
    }
    setState(() => busy = true);
    try {
      bool success;
      if (!enabled) {
        await PinSecurity.enable(newPin.text);
        success = true;
      } else if (disable) {
        success = await PinSecurity.disable(oldPin.text);
      } else {
        success = await PinSecurity.change(oldPin.text, newPin.text);
      }
      if (!mounted) return;
      if (success) {
        oldPin.clear(); newPin.clear(); confirmPin.clear();
        await refresh();
        if (mounted) notify(context, disable ? 'PIN dinonaktifkan' : 'PIN keamanan berhasil disimpan');
      } else {
        notify(context, 'PIN lama salah atau terkunci sementara');
      }
    } catch (e) {
      if (mounted) notify(context, 'Tidak berhasil: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Widget pinField(TextEditingController c, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c,
      obscureText: true, maxLength: 6, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: inputDecoration(title, icon: Icons.password_rounded).copyWith(counterText: '')));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Keamanan & PIN')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
          size: 42, color: enabled ? Colors.green : brandBlue),
        const SizedBox(height: 12),
        Text(enabled ? 'PIN perlindungan aktif' : 'Aktifkan PIN untuk aplikasi',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
        const SizedBox(height: 6),
        Text('PIN 6 digit diminta saat membuka aplikasi serta setelah aplikasi berada di latar belakang setidaknya 20 detik.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      const SizedBox(height: 15),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (enabled) pinField(oldPin, 'PIN saat ini'),
        pinField(newPin, 'PIN baru (6 angka)'),
        pinField(confirmPin, 'Ulangi PIN baru'),
        FilledButton.icon(onPressed: busy ? null : () => submit(disable: false),
          icon: const Icon(Icons.save_rounded),
          label: Text(busy ? 'Memproses...' : (enabled ? 'Ganti PIN' : 'Aktifkan PIN'))),
        if (enabled) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: busy ? null : () => submit(disable: true),
            icon: const Icon(Icons.lock_open_rounded), label: const Text('Nonaktifkan PIN')),
        ],
      ])),
      const SizedBox(height: 15),
      const Surface(child: Text('Keamanan: PIN disimpan sebagai hash dengan salt, dan 5 percobaan gagal akan menyebabkan jeda 30 detik. PIN hanya membatasi akses dari UI, tidak mengamankan data terhadap perangkat yang di-root atau backup yang disalin. Jika PIN lupa, pemulihan melalui aplikasi belum tersedia.')),
    ]),
  );
}
