import '../../core/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pin_security.dart';
import '../../services/biometric_security.dart';
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
  bool checkFailed = false;
  DateTime? backgrounded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    if (mounted) setState(() { checking = true; checkFailed = false; });
    try {
      final required = await PinSecurity.enabled.timeout(
        const Duration(seconds: 10));
      if (mounted) setState(() {
        locked = required;
        checking = false;
      });
    } catch (_) {
      // Fail closed: never bypass an existing PIN after a storage error.
      if (mounted) setState(() {
        locked = true;
        checkFailed = true;
        checking = false;
      });
    }
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
    try {
      if (await PinSecurity.enabled && mounted) setState(() => locked = true);
    } catch (_) {
      // A storage failure must not accidentally leave a previously secured
      // session open. Ask the user to retry reading their security settings.
      if (mounted) setState(() { locked = true; checkFailed = true; });
    }
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (checkFailed) {
      return Scaffold(body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, size: 46),
          const SizedBox(height: 16),
          const Text('Pengaturan keamanan belum bisa dibaca',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Data tetap tersimpan. Jangan hapus data aplikasi. '
            'Periksa penyimpanan Android, lalu coba lagi.',
            textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: initialize,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi')),
        ],
      )))));
    }
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
  bool biometricsReady = false;
  bool faceReady = false;
  bool facePromptAttempted = false;
  String message = 'Masukkan PIN 6 digit untuk membuka aplikasi';

  @override
  void initState() { super.initState(); checkBiometrics(); }
  Future<void> checkBiometrics() async {
    try {
      final enabled = await BiometricSecurity.isEnabled;
      final available = enabled && await BiometricSecurity.available;
      final face = available && await BiometricSecurity.facePreferred &&
        await BiometricSecurity.faceAvailable;
      if (!mounted) return;
      setState(() { biometricsReady = available; faceReady = face; });
      if (face && !facePromptAttempted) {
        facePromptAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !busy) unlockBiometric();
        });
      }
    } catch (_) {
      // Biometric failure must never prevent PIN unlock.
      if (mounted) setState(() => biometricsReady = false);
    }
  }

  Future<void> unlockBiometric() async {
    if (busy || !biometricsReady) return;
    setState(() => busy = true);
    try {
      final success = await BiometricSecurity.authenticate();
      if (!mounted) return;
      if (success) { widget.onUnlocked(); return; }
      setState(() => message = 'Verifikasi gagal; gunakan PIN atau coba lagi.');
    } catch (_) {
      if (mounted) setState(() => message = 'Biometrik tidak tersedia. Gunakan PIN.');
    } finally { if (mounted) setState(() => busy = false); }
  }

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
    } catch (_) {
      if (mounted) setState(() => message =
        'PIN belum dapat diperiksa. Data tidak dihapus; coba lagi.');
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
        if (biometricsReady) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: busy ? null : unlockBiometric,
            icon: Icon(faceReady ? Icons.face_retouching_natural_rounded
              : Icons.fingerprint_rounded),
            label: Text(faceReady ? 'Verifikasi Wajah / Biometrik'
              : 'Buka dengan Biometrik')),
        ],
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
  bool biometricsEnabled = false;
  bool biometricsAvailable = false;
  // BUILD30_PIN_FACE_UI: face is optional, PIN is always the fallback.
  bool faceAvailable = false;
  bool facePreferred = false;

  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    final value = await PinSecurity.enabled;
    final biometric = await BiometricSecurity.isEnabled;
    final available = await BiometricSecurity.available;
    final face = await BiometricSecurity.faceAvailable;
    final preferred = await BiometricSecurity.facePreferred;
    if (mounted) setState(() {
      enabled = value;
      biometricsEnabled = biometric;
      biometricsAvailable = available;
      faceAvailable = face;
      facePreferred = preferred;
    });
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
        if (disable) {
          await BiometricSecurity.disableFacePreference();
          await BiometricSecurity.disable();
        }
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

  Future<void> toggleBiometrics(bool value) async {
    setState(() => busy = true);
    try {
      if (value) {
        final result = await BiometricSecurity.enable();
        if (mounted) notify(context, result ? 'Biometrik diaktifkan' :
          'Verifikasi gagal. Pastikan PIN aktif dan biometrik disiapkan di Android.');
      } else {
        await BiometricSecurity.disableFacePreference();
        await BiometricSecurity.disable();
        if (mounted) notify(context, 'Biometrik dinonaktifkan');
      }
      await refresh();
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> toggleFace(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (value) {
        final approved = await BiometricSecurity.enableFacePreference();
        if (mounted) notify(context, approved
          ? 'Prioritas wajah Android diaktifkan.'
          : 'Wajah belum tersedia atau verifikasi dibatalkan. Gunakan PIN.');
      } else {
        await BiometricSecurity.disableFacePreference();
        if (mounted) notify(context, 'Prioritas wajah dinonaktifkan');
      }
      await refresh();
    } catch (e) {
      if (mounted) notify(context, 'Tidak bisa mengubah pengaturan wajah: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
      Surface(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.fingerprint_rounded, color: brandBlue),
        title: const Text('Buka dengan Biometrik',
          style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(biometricsAvailable
          ? 'Wajah atau sidik jari, sesuai kemampuan perangkat Android'
          : 'Belum tersedia; siapkan biometrik di Pengaturan Android'),
        value: biometricsEnabled && enabled,
        onChanged: !enabled || !biometricsAvailable || busy ? null : toggleBiometrics,
      )),
      const SizedBox(height: 12),
      Surface(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.face_retouching_natural_rounded,
          color: brandBlue),
        title: const Text('Prioritaskan Scan Wajah Android',
          style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(faceAvailable
          ? 'Tampilkan prompt biometrik saat membuka kunci. '
            'Android dapat menawarkan sensor lain; PIN selalu tersedia.'
          : 'Face Unlock belum terdeteksi oleh API biometrik Android pada HP ini.'),
        value: facePreferred && enabled && faceAvailable,
        onChanged: !enabled || !faceAvailable || busy ? null : toggleFace,
      )),
      const SizedBox(height: 10),
      const Surface(child: Text('Biometrik wajah mengikuti kemampuan sensor dan '
        'kebijakan Android. Aplikasi tidak menyimpan foto wajah atau template '
        'biometrik. Pastikan PIN aktif sebagai metode pemulihan.')),
      const SizedBox(height: 15),
      const Surface(child: Text('Keamanan: PIN disimpan sebagai hash dengan salt, dan 5 percobaan gagal akan menyebabkan jeda 30 detik. PIN hanya membatasi akses dari UI, tidak mengamankan data terhadap perangkat yang di-root atau backup yang disalin. Jika PIN lupa, pemulihan melalui aplikasi belum tersedia.')),
    ]),
  );
}
