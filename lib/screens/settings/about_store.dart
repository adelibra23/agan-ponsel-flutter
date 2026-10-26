import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agan_ponsel/services/store_about_profile.dart';
import '../../core/format.dart';
import '../../widgets/store_logo.dart';

/// BUILD31_ABOUT_STORE — locally editable public business profile and contact.
class AboutStoreScreen extends StatefulWidget {
  const AboutStoreScreen({super.key});

  @override
  State<AboutStoreScreen> createState() => _AboutStoreScreenState();
}

class _AboutStoreScreenState extends State<AboutStoreScreen> {
  late Future<StoreAboutProfile> profile;
  late Future<PackageInfo?> package;

  @override
  void initState() {
    super.initState();
    profile = StoreAboutProfile.load();
    package = PackageInfo.fromPlatform().then<PackageInfo?>((info) => info)
        .catchError((Object _) => null);
  }

  void reload() => setState(() => profile = StoreAboutProfile.load());

  Future<void> edit(StoreAboutProfile current) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _EditAboutStoreScreen(initial: current),
    ));
    if (saved == true && mounted) reload();
  }

  Future<void> launchContact(Uri? uri, String title) async {
    if (uri == null) {
      notify(context, '$title belum valid. Sunting kontak toko terlebih dahulu.');
      return;
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) notify(context, 'Tidak bisa membuka $title di perangkat ini.');
    } catch (error) {
      if (mounted) notify(context, 'Tidak bisa membuka $title: $error');
    }
  }

  Future<void> shareProfile(StoreAboutProfile item) async {
    try {
      await SharePlus.instance.share(ShareParams(
        text: item.toShareText(),
        subject: 'Kontak ${item.name}',
      ));
    } catch (error) {
      if (mounted) notify(context, 'Gagal membagikan profil: $error');
    }
  }

  Future<void> copyProfile(StoreAboutProfile item) async {
    await Clipboard.setData(ClipboardData(text: item.toShareText()));
    if (mounted) notify(context, 'Informasi toko disalin');
  }

  Widget contactTile(IconData icon, String label, String value, Uri? uri) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Icon(uri == null ? Icons.edit_outlined : Icons.open_in_new_rounded,
          size: 19),
      onTap: () => launchContact(uri, label),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StoreAboutProfile>(
    future: profile,
    builder: (context, snapshot) {
      final shop = snapshot.data;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tentang AGAN PONSEL'),
          actions: [
            if (shop != null)
              IconButton(
                tooltip: 'Sunting tentang AGAN PONSEL',
                onPressed: () => edit(shop),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (shop != null)
              IconButton(
                tooltip: 'Bagikan kontak toko',
                onPressed: () => shareProfile(shop),
                icon: const Icon(Icons.ios_share_rounded),
              ),
          ],
        ),
        body: snapshot.hasError
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal membaca profil toko: ${snapshot.error}'),
              ))
            : shop == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    key: const PageStorageKey('about-agan-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 38),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF08255A), Color(0xFF1764D6),
                              Color(0xFF1BB4D7)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF1764D6).withValues(alpha: .17),
                            blurRadius: 22, offset: const Offset(0, 9),
                          )],
                        ),
                        child: Column(children: [
                          const StoreLogo(size: 78),
                          const SizedBox(height: 15),
                          Text(shop.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 25,
                              fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 7),
                          FutureBuilder<PackageInfo?>(
                            future: package,
                            builder: (context, info) => Text(
                              info.data == null
                                  ? 'Informasi versi aplikasi'
                                  : 'Versi ${info.data!.version} • Build ${info.data!.buildNumber}',
                              style: const TextStyle(color: Colors.white70,
                                fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            shop.description.trim().isEmpty
                                ? 'Pusat kebutuhan ponsel, aksesoris, service dan layanan toko.'
                                : shop.description.trim(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white,
                              height: 1.45, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.tonalIcon(
                            onPressed: () => edit(shop),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Sunting Profil Toko'),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      const _AboutSectionTitle('Kontak AGAN PONSEL'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16,
                            vertical: 8),
                          child: Column(children: [
                            if (shop.phone.trim().isNotEmpty)
                              contactTile(Icons.call_outlined, 'Telepon',
                                shop.phone, ShopContactLinks.phoneUri(shop.phone)),
                            if (shop.whatsapp.trim().isNotEmpty)
                              contactTile(Icons.chat_outlined, 'WhatsApp',
                                shop.whatsapp, ShopContactLinks.whatsappUri(shop.whatsapp)),
                            if (shop.email.trim().isNotEmpty)
                              contactTile(Icons.alternate_email_rounded, 'Email',
                                shop.email, ShopContactLinks.emailUri(shop.email)),
                            if (shop.instagram.trim().isNotEmpty)
                              contactTile(Icons.camera_alt_outlined, 'Instagram',
                                '@${shop.instagram.replaceFirst(RegExp(r'^@'), '')}',
                                ShopContactLinks.instagramUri(shop.instagram)),
                            if (shop.website.trim().isNotEmpty)
                              contactTile(Icons.language_rounded, 'Situs Web',
                                shop.website, ShopContactLinks.websiteUri(shop.website)),
                            if (shop.phone.trim().isEmpty &&
                                shop.whatsapp.trim().isEmpty &&
                                shop.email.trim().isEmpty &&
                                shop.instagram.trim().isEmpty &&
                                shop.website.trim().isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Column(children: [
                                  const Text('Kontak toko belum diatur.'),
                                  TextButton.icon(
                                    onPressed: () => edit(shop),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Tambah Kontak'),
                                  ),
                                ]),
                              ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 17),
                      const _AboutSectionTitle('Alamat & Jam Operasional'),
                      Card(child: Padding(
                        padding: const EdgeInsets.all(17),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(shop.address.trim().isEmpty
                                    ? 'Alamat belum diisi' : shop.address)),
                              ]),
                            const SizedBox(height: 14),
                            Row(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.schedule_outlined, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(shop.hours.trim().isEmpty
                                    ? 'Jam operasional belum diatur' : shop.hours)),
                              ]),
                          ],
                        ),
                      )),
                      const SizedBox(height: 17),
                      const _AboutSectionTitle('Tentang Aplikasi'),
                      const Card(child: Padding(
                        padding: EdgeInsets.all(17),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Operasional AGAN PONSEL',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                            SizedBox(height: 7),
                            Text('Kelola penjualan, produk, service, piutang, '
                              'pengeluaran, laporan dan stok dalam satu aplikasi. '
                              'Pencatatan utama dapat digunakan secara offline '
                              'dan data transaksi tersimpan lokal di perangkat. '
                              'Backup Google Drive, AGANA berbasis API, dan '
                              'layanan WhatsApp memerlukan akses internet '
                              'serta pengaturan yang sesuai.',
                              style: TextStyle(height: 1.45)),
                            SizedBox(height: 9),
                            Text('Kunci PIN dan biometrik membatasi akses layar, '
                              'tetapi tidak mengenkripsi backup. '
                              'Cadangkan data toko sebelum mengganti atau menghapus aplikasi.',
                              style: TextStyle(fontSize: 12, height: 1.45)),
                          ],
                        ),
                      )),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => copyProfile(shop),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Salin Kontak'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton.icon(
                          onPressed: () => shareProfile(shop),
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Bagikan'),
                        )),
                      ]),
                    ],
                  ),
      );
    },
  );
}

class _AboutSectionTitle extends StatelessWidget {
  final String label;
  const _AboutSectionTitle(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    )),
  );
}

class _EditAboutStoreScreen extends StatefulWidget {
  final StoreAboutProfile initial;
  const _EditAboutStoreScreen({required this.initial});

  @override
  State<_EditAboutStoreScreen> createState() => _EditAboutStoreScreenState();
}

class _EditAboutStoreScreenState extends State<_EditAboutStoreScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController address;
  late final TextEditingController hours;
  late final TextEditingController phone;
  late final TextEditingController whatsapp;
  late final TextEditingController email;
  late final TextEditingController instagram;
  late final TextEditingController website;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.initial;
    name = TextEditingController(text: current.name);
    description = TextEditingController(text: current.description);
    address = TextEditingController(text: current.address);
    hours = TextEditingController(text: current.hours);
    phone = TextEditingController(text: current.phone);
    whatsapp = TextEditingController(text: current.whatsapp);
    email = TextEditingController(text: current.email);
    instagram = TextEditingController(text: current.instagram);
    website = TextEditingController(text: current.website);
  }

  @override
  void dispose() {
    for (final controller in [name, description, address, hours, phone,
      whatsapp, email, instagram, website]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await StoreAboutProfile(
        name: name.text,
        description: description.text,
        address: address.text,
        hours: hours.text,
        phone: phone.text,
        whatsapp: whatsapp.text,
        email: email.text,
        instagram: instagram.text,
        website: website.text,
      ).save();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) notify(context, 'Gagal menyimpan profil: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(TextEditingController controller, String label, {
    int lines = 1,
    int maxLength = 100,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: lines > 1,
      ),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sunting Tentang AGAN PONSEL')),
    body: Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AboutSectionTitle('Profil Toko'),
          field(name, 'Nama toko', maxLength: 80,
            validator: (v) => v == null || v.trim().isEmpty
              ? 'Nama toko wajib diisi' : null),
          field(description, 'Deskripsi AGAN PONSEL', lines: 4,
            maxLength: 600, keyboard: TextInputType.multiline),
          field(address, 'Alamat toko', lines: 2, maxLength: 200,
            keyboard: TextInputType.streetAddress),
          field(hours, 'Jam operasional', lines: 2, maxLength: 160),
          const SizedBox(height: 8),
          const _AboutSectionTitle('Kontak Toko'),
          field(phone, 'Nomor telepon toko', maxLength: 24,
            keyboard: TextInputType.phone,
            validator: (v) => (v?.trim().isEmpty ?? true) ||
                ShopContactLinks.phoneUri(v!) != null
                ? null : 'Nomor telepon tidak valid'),
          field(whatsapp, 'Nomor WhatsApp toko', maxLength: 24,
            keyboard: TextInputType.phone,
            validator: (v) => (v?.trim().isEmpty ?? true) ||
                ShopContactLinks.whatsappNumber(v!) != null
                ? null : 'Gunakan nomor WA Indonesia, misalnya 08xxx'),
          field(email, 'Email toko', maxLength: 120,
            keyboard: TextInputType.emailAddress,
            validator: (v) => ShopContactLinks.validEmail(v ?? '')
              ? null : 'Alamat email tidak valid'),
          field(instagram, 'Username Instagram (opsional)', maxLength: 31,
            validator: (v) => (v?.trim().isEmpty ?? true) ||
                ShopContactLinks.instagramUri(v!) != null
                ? null : 'Username Instagram tidak valid'),
          field(website, 'Situs web (opsional)', maxLength: 160,
            keyboard: TextInputType.url,
            validator: (v) => (v?.trim().isEmpty ?? true) ||
                ShopContactLinks.websiteUri(v!) != null
                ? null : 'Gunakan nama domain atau URL HTTPS yang valid'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'Menyimpan...' : 'Simpan Tentang Toko'),
          ),
          const SizedBox(height: 14),
          Text('Data profil tersimpan secara lokal dan disertakan dalam backup. '
            'Tautan kontak hanya dibuka saat dipilih pengguna.',
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
