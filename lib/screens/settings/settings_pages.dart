import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/backup_service.dart';
import '../../services/printer_service.dart';
import '../../services/store_brand.dart';
import '../../widgets/store_logo.dart';
import '../../widgets/kit.dart';

class SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const SettingsCard({super.key, required this.icon, required this.color,
    required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Surface(padding: EdgeInsets.zero, child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      leading: Container(width: 46, height: 46,
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(15)),
        child: Icon(icon, color: color)),
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11.5)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant),
    )),
  );
}

class SettingsPageLayout extends StatelessWidget {
  final String title;
  final Widget child;
  const SettingsPageLayout({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
    body: SafeArea(child: child),
  );
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final form = GlobalKey<FormState>();
  final owner = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final shop = TextEditingController();
  final address = TextEditingController();
  final footer = TextEditingController();
  bool loading = true;
  bool saving = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    owner.text = prefs.getString('local_owner_name') ?? 'Pemilik Toko';
    phone.text = prefs.getString('local_owner_phone') ?? '';
    email.text = prefs.getString('local_owner_email') ?? '';
    shop.text = prefs.getString('local_shop_name') ?? 'AGAN PONSEL';
    address.text = prefs.getString('local_shop_address') ?? 'Sekeladi, Tanah Putih, Riau';
    footer.text = prefs.getString('local_receipt_footer') ?? 'Terima kasih sudah berbelanja!';
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final text in [owner, phone, email, shop, address, footer]) { text.dispose(); }
    super.dispose();
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final fields = <String, String>{
        'local_owner_name': owner.text.trim(),
        'local_owner_phone': phone.text.trim(),
        'local_owner_email': email.text.trim(),
        'local_shop_name': shop.text.trim(),
        'local_shop_address': address.text.trim(),
        'local_receipt_footer': footer.text.trim(),
      };
      for (final field in fields.entries) { await prefs.setString(field.key, field.value); }
      if (mounted) notify(context, 'Profil akun dan toko tersimpan di Android');
    } catch (e) {
      if (mounted) notify(context, 'Gagal menyimpan: $e');
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => SettingsPageLayout(title: 'Akun & Profil Toko',
    child: loading ? const ScreenLoading() : Form(key: form, child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
        Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [Color(0xFF073FC0), Color(0xFF0A92EA)])),
          child: Row(children: [
            const StoreLogo(size: 58),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Identitas Pengelola', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 17)),
              SizedBox(height: 5),
              Text('Profil lokal; tanpa akun cloud atau login online', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ])),
        const SizedBox(height: 18),
        const SectionTitle('Akun lokal'),
        _field(owner, 'Nama pengelola', icon: Icons.person_outline_rounded, mandatory: true),
        _field(phone, 'Nomor HP', icon: Icons.phone_outlined, type: TextInputType.phone),
        _field(email, 'Email (opsional)', icon: Icons.mail_outline_rounded, type: TextInputType.emailAddress),
        const SizedBox(height: 17),
        const SectionTitle('Identitas toko'),
        _field(shop, 'Nama toko', icon: Icons.storefront_outlined, mandatory: true),
        _field(address, 'Alamat toko', icon: Icons.place_outlined, lines: 2),
        _field(footer, 'Pesan footer struk', icon: Icons.receipt_long_outlined, lines: 2),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: saving ? null : save,
          icon: const Icon(Icons.save_rounded), label: Text(saving ? 'Menyimpan...' : 'Simpan Profil')),
        const SizedBox(height: 12),
        Text('Profil ini hanya tersimpan di perangkat dan ikut dalam backup. Tidak membuat akun pengguna online.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    )));

  Widget _field(TextEditingController c, String name, {IconData? icon,
    bool mandatory = false, int lines = 1, TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextFormField(
      controller: c, maxLines: lines, keyboardType: type,
      decoration: inputDecoration(name, icon: icon),
      validator: mandatory ? (v) => (v == null || v.trim().isEmpty) ? '$name wajib diisi' : null : null,
    ),
  );
}

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});
  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool busy = false;
  BackupPreview? preview;

  Future<void> backup() async {
    setState(() => busy = true);
    try {
      final result = await BackupService.exportBackup();
      if (mounted) notify(context, result == null ? 'Penyimpanan backup dibatalkan' : 'Backup berhasil disimpan. Simpan file di tempat aman.');
    } catch (e) { if (mounted) notify(context, 'Backup gagal: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> chooseRestore() async {
    setState(() { busy = true; preview = null; });
    try {
      final picked = await BackupService.chooseBackup();
      if (mounted) setState(() => preview = picked);
    } catch (e) { if (mounted) notify(context, 'File backup tidak valid: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> restore() async {
    final current = preview;
    if (current == null) return;
    final confirmText = TextEditingController();
    final allowed = await showDialog<bool>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Timpa semua data toko?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Restore akan MENGGANTI seluruh data produk, pelanggan, service, transaksi dan riwayat pada HP ini. Buat backup saat ini terlebih dahulu.'),
          const SizedBox(height: 14),
          TextField(controller: confirmText,
            onChanged: (_) => update(() {}),
            decoration: inputDecoration('Ketik PULIHKAN untuk melanjutkan')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: confirmText.text == 'PULIHKAN'
            ? () => Navigator.pop(ctx, true) : null,
            child: const Text('Timpa & Pulihkan')),
        ],
      )));
    confirmText.dispose();
    if (allowed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await BackupService.restore(current);
      if (mounted) {
        setState(() => preview = null);
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Restore berhasil'),
          content: const Text('Semua data sudah dipulihkan. Kembali ke Beranda dan buka ulang aplikasi bila tampilan lama masih tersimpan dalam cache.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ));
      }
    } catch (e) { if (mounted) notify(context, 'Restore dibatalkan / gagal: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => SettingsPageLayout(title: 'Backup & Restore',
    child: ListView(padding: const EdgeInsets.all(16), children: [
      const PageIntro('Lindungi data toko', 'Backup manual sebelum ganti HP, uninstall, atau hapus data'),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.cloud_download_outlined, size: 33, color: brandBlue),
        const SizedBox(height: 11),
        const Text('Buat Backup SQLite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('Ekspor snapshot SQLite, profil, dan foto produk ke JSON dengan checksum SHA-256.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: busy ? null : backup, icon: const Icon(Icons.backup_outlined),
          label: const Text('Simpan File Backup'))),
      ])),
      const SizedBox(height: 13),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.settings_backup_restore_rounded, size: 33, color: Color(0xFF8E58D7)),
        const SizedBox(height: 11),
        const Text('Pulihkan dari File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('Pilih file backup AGAN PONSEL. Aplikasi memeriksa format, checksum, dan tabel sebelum menimpa data.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: busy ? null : chooseRestore, icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Pilih File Restore'))),
      ])),
      if (preview != null) ...[
        const SizedBox(height: 13),
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Pill('Backup terverifikasi', color: Color(0xFF009D73)),
          const SizedBox(height: 10),
          Text(preview!.filename, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('Dibuat: ${preview!.createdAt}', style: const TextStyle(fontSize: 12)),
          Text('${preview!.count} baris data • ${preview!.countOf('products')} produk • ${preview!.countOf('services')} service',
            style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 13),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: busy ? null : restore, icon: const Icon(Icons.restore),
            label: const Text('Pulihkan Data Ini'))),
        ])),
      ],
      const SizedBox(height: 16),
      Surface(child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFE28B16)),
        const SizedBox(width: 10),
        Expanded(child: Text('File JSON backup tidak dienkripsi. Data pelanggan dan transaksi di dalamnya dapat dibaca oleh orang yang memiliki file. Simpan di tempat aman.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ])),
      if (busy) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
    ]));
}

class BluetoothPrinterScreen extends StatefulWidget {
  const BluetoothPrinterScreen({super.key});
  @override
  State<BluetoothPrinterScreen> createState() => _BluetoothPrinterScreenState();
}

class _BluetoothPrinterScreenState extends State<BluetoothPrinterScreen> {
  List<BluetoothInfo> devices = [];
  String? selected;
  bool busy = false;
  bool connected = false;
  int size = 58;

  @override
  void initState() { super.initState(); initialize(); }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final attached = await AganPrinter.connected;
    if (!mounted) return;
    setState(() {
      selected = prefs.getString(AganPrinter.addressKey);
      size = prefs.getInt(AganPrinter.paperKey) ?? 58;
      connected = attached;
    });
  }

  Future<void> listPrinters() async {
    setState(() => busy = true);
    try {
      final paired = await AganPrinter.paired();
      if (mounted) {
        setState(() => devices = paired);
        if (paired.isEmpty) notify(context, 'Belum ada perangkat Bluetooth berpasangan. Pair printer lewat pengaturan HP.');
      }
    } catch (e) { if (mounted) notify(context, '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> connect(String mac) async {
    setState(() => busy = true);
    try {
      final ok = await AganPrinter.connect(mac);
      if (mounted) {
        setState(() { selected = mac; connected = ok; });
        notify(context, ok ? 'Printer berhasil dihubungkan' : 'Printer tidak merespons. Pastikan printer aktif dan berpasangan.');
      }
    } catch (e) { if (mounted) notify(context, 'Tidak bisa terhubung: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> test() async {
    setState(() => busy = true);
    try {
      await AganPrinter.printText('           AGAN PONSEL\n--------------------------------\n      TEST PRINTER BERHASIL\n--------------------------------\nPrinter Bluetooth ESC/POS\n');
      if (mounted) notify(context, 'Perintah cetak berhasil dikirim ke printer');
    } catch (e) { if (mounted) notify(context, 'Gagal mencetak: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => SettingsPageLayout(title: 'Printer Bluetooth',
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF083BBD), Color(0xFF159EE9)])),
        child: Row(children: [
          const Icon(Icons.print_rounded, color: Colors.white, size: 38),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(connected ? 'Printer Terhubung' : 'Siapkan Printer Thermal',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 4),
            Text(selected ?? 'Printer Bluetooth Classic ESC/POS 58/80 mm',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ])),
      const SizedBox(height: 18),
      const SectionTitle('Ukuran kertas'),
      SegmentedButton<int>(segments: const [
        ButtonSegment(value: 58, label: Text('58 mm'), icon: Icon(Icons.receipt_outlined)),
        ButtonSegment(value: 80, label: Text('80 mm'), icon: Icon(Icons.receipt_long_rounded)),
      ], selected: {size}, onSelectionChanged: busy ? null : (values) async {
        final next = values.first;
        await AganPrinter.setPaperSize(next);
        if (mounted) setState(() => size = next);
      }),
      const SizedBox(height: 17),
      FilledButton.icon(onPressed: busy ? null : listPrinters,
        icon: const Icon(Icons.bluetooth_searching_rounded),
        label: const Text('Cari Printer yang Sudah Pairing')),
      const SizedBox(height: 15),
      for (final device in devices) ...[
        Surface(child: ListTile(contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.print_outlined)),
          title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(device.macAdress, style: const TextStyle(fontSize: 11)),
          trailing: selected == device.macAdress && connected
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00A77A))
            : const Icon(Icons.bluetooth_connected),
          onTap: busy ? null : () => connect(device.macAdress))),
        const SizedBox(height: 9),
      ],
      if (selected != null) ...[
        const SizedBox(height: 9),
        OutlinedButton.icon(onPressed: busy ? null : test,
          icon: const Icon(Icons.print_rounded), label: const Text('Cetak Halaman Tes')),
        if (connected) TextButton.icon(onPressed: busy ? null : () async {
          await AganPrinter.disconnect();
          if (mounted) setState(() => connected = false);
        }, icon: const Icon(Icons.link_off_rounded), label: const Text('Putuskan koneksi')),
      ],
      const SizedBox(height: 13),
      Surface(child: Text('Pasangkan printer lebih dahulu di Pengaturan Bluetooth Android. Hanya printer thermal Bluetooth Classic dengan ESC/POS yang didukung; printer BLE/non-ESC/POS mungkin tidak kompatibel.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
      if (busy) const Center(child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator())),
    ]));
}

class DatabaseInfoScreen extends StatefulWidget {
  const DatabaseInfoScreen({super.key});
  @override
  State<DatabaseInfoScreen> createState() => _DatabaseInfoScreenState();
}

class _DatabaseInfoScreenState extends State<DatabaseInfoScreen> {
  late Future<Map<String, Object>> stats;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() => stats = load());

  Future<Map<String, Object>> load() async {
    final db = await AppDatabase.instance;
    final rows = <String, int>{};
    for (final name in BackupService.tables) {
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $name')) ?? 0;
      rows[name] = count;
    }
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    return {'version': await db.getVersion(), 'location': db.path, 'tables': rows,
      'integrity': '${integrity.first.values.first}'};
  }

  @override
  Widget build(BuildContext context) => SettingsPageLayout(title: 'Database SQLite',
    child: FutureBuilder<Map<String, Object>>(future: stats, builder: (ctx, snap) {
      if (snap.hasError) return EmptyView(icon: Icons.error_outline, title: 'Gagal membaca database', subtitle: '${snap.error}');
      if (!snap.hasData) return const ScreenLoading();
      final v = snap.data!;
      final tables = v['tables'] as Map<String, int>;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.storage_rounded, size: 36, color: brandBlue),
          const SizedBox(height: 12),
          const Text('SQLite Perangkat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text('Skema versi ${v['version']} • Integritas: ${v['integrity']}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Divider(height: 25),
          Text('Lokasi privat Android:\n${v['location']}', style: const TextStyle(fontSize: 12)),
        ])),
        const SizedBox(height: 18),
        const SectionTitle('Jumlah data per tabel'),
        for (final table in tables.entries) ...[
          Surface(child: Row(children: [
            Expanded(child: Text(table.key, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${table.value}', style: const TextStyle(fontWeight: FontWeight.w900, color: brandBlue)),
          ])),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh_rounded),
          label: const Text('Periksa Ulang')),
      ]);
    }));
}

class AboutAganScreen extends StatelessWidget {
  const AboutAganScreen({super.key});
  @override
  Widget build(BuildContext context) => SettingsPageLayout(title: 'Tentang Aplikasi',
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF0736B1), Color(0xFF159DEB)])),
        child: Column(children: [
          const StoreLogo(size: 84),
          SizedBox(height: 15),
          Text('AGAN PONSEL', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(height: 5),
          Text('Flutter Offline • v0.9.3 Build 16', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 8),
          Text('Operasional toko, kasir, dan service HP dalam satu aplikasi',
            style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
        ])),
      const SizedBox(height: 18),
      const SectionTitle('Tentang versi ini'),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dirancang untuk bekerja tanpa server komputer.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 12),
        for (final feature in const [
          'Kasir dan manajemen stok SQLite lokal',
          'Tiket service multi-tab dan timeline pengerjaan',
          'Backup & Restore SQLite dan foto produk ke JSON',
          'Scan barcode produk dengan kamera (offline)',
          'Foto produk di Kasir dan Inventaris',
          'Kunci aplikasi dengan PIN dan biometrik Android',
          'Impor pelanggan yang dipilih dari kontak HP',
          'Logo toko kustom dan saldo kas privat',
          'Catatan tugas dan target omzet harian',
          'Piutang, cicilan, pusat pengingat jatuh tempo',
          'Template warna aplikasi dan pesan penagihan',
          'Splash AG Orbit Holographic dengan gerak 3D',
          'AGANA AI dengan API key pribadi, model gratis sesuai penyedia',
          'API key AI tidak dicadangkan; data toko tidak dikirim otomatis ke penyedia AI',
          'Printer thermal Bluetooth ESC/POS 58/80 mm',
          'Profil akun pengelola dan identitas toko lokal',
          'Laporan, transaksi digital dan riwayat penjualan',
        ]) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_circle_rounded, size: 15,
              color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 9),
            Expanded(child: Text(feature, style: TextStyle(
              fontSize: 12.7, height: 1.35,
              color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ])),
      ])),
      const SizedBox(height: 14),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pemberitahuan', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('AGAN PONSEL adalah alat pencatatan toko. Top up, transfer bank, OTP dan WhatsApp otomatis tidak diproses oleh aplikasi offline ini.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Text('Backup tersimpan di lokasi yang dipilih pengguna. Menghapus aplikasi dapat menghapus database lokal jika belum dicadangkan.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
    ]));
}


class StoreBrandSettingsScreen extends StatefulWidget {
  const StoreBrandSettingsScreen({super.key});
  @override
  State<StoreBrandSettingsScreen> createState() => _StoreBrandSettingsScreenState();
}

class _StoreBrandSettingsScreenState extends State<StoreBrandSettingsScreen> {
  bool busy = false;
  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final changed = await StoreBrand.pickLogo();
      if (changed && mounted) notify(context, 'Logo toko berhasil diganti');
    } catch (e) { if (mounted) notify(context, 'Tidak dapat menggunakan gambar: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> remove() async {
    setState(() => busy = true);
    try {
      await StoreBrand.removeLogo();
      if (mounted) notify(context, 'Logo kembali ke identitas AG');
    } catch (e) { if (mounted) notify(context, '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => SettingsPageLayout(title: 'Logo & Branding Toko',
    child: ListView(padding: const EdgeInsets.all(17), children: [
      Container(padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(27),
          gradient: const LinearGradient(colors: [Color(0xFF052C98), brandBlue, Color(0xFF0994E4)])),
        child: const Column(children: [
          StoreLogo(size: 102),
          SizedBox(height: 15),
          Text('AGAN PONSEL', style: TextStyle(fontSize: 23,
            fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.8)),
          SizedBox(height: 6),
          Text('Identitas toko, tersimpan di HP', style: TextStyle(color: Colors.white70)),
        ])),
      const SizedBox(height: 21),
      const SectionTitle('Logo header'),
      const Surface(child: Text('Pilih gambar JPG, PNG atau WebP maksimal 2 MB. Logo akan dipakai di header dan halaman profil, serta disertakan dalam backup terbaru.')),
      const SizedBox(height: 15),
      FilledButton.icon(onPressed: busy ? null : pick,
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Ganti Logo dari Galeri')),
      const SizedBox(height: 9),
      OutlinedButton.icon(onPressed: busy ? null : remove,
        icon: const Icon(Icons.restore_rounded), label: const Text('Kembalikan Logo AG')),
      if (busy) const Center(child: Padding(padding: EdgeInsets.all(14),
        child: CircularProgressIndicator())),
      const SizedBox(height: 14),
      Text('Logo disimpan dalam folder privat aplikasi. Jangan uninstall sebelum membuat backup.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ]));
}
