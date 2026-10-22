import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/background_jobs.dart';
import '../../services/drive_backup_service.dart';

class DriveBackupSettingsScreen extends StatefulWidget {
  const DriveBackupSettingsScreen({super.key});
  @override
  State<DriveBackupSettingsScreen> createState() => _DriveBackupSettingsScreenState();
}

class _DriveBackupSettingsScreenState extends State<DriveBackupSettingsScreen> {
  bool loading = true, busy = false, enabled = false, wifiOnly = true;
  String frequency = 'daily', email = '', lastOk = '', lastName = '', lastError = '';
  int hour = 2, minute = 0, weekday = 1, monthDay = 1, retain = 7;
  final clientId = TextEditingController();

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { clientId.dispose(); super.dispose(); }

  Future<void> load() async {
    final config = await DriveBackupConfig.load();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      enabled = config.enabled; frequency = config.frequency;
      hour = config.hour; minute = config.minute;
      weekday = config.weekday; monthDay = config.monthDay;
      wifiOnly = config.wifiOnly; retain = config.retain;
      clientId.text = prefs.getString('agan_drive_web_client_id') ?? '';
      email = prefs.getString('agan_drive_email') ?? '';
      lastOk = prefs.getString('agan_drive_last_ok') ?? '';
      lastName = prefs.getString('agan_drive_last_name') ?? '';
      lastError = prefs.getString('agan_drive_last_error') ?? '';
      loading = false;
    });
  }

  Future<void> save() async {
    if (enabled && email.isEmpty) {
      message('Hubungkan Google Drive sebelum mengaktifkan backup otomatis.');
      return;
    }
    setState(() => busy = true);
    try {
      await DriveBackupConfig(enabled: enabled, frequency: frequency,
        hour: hour, minute: minute, weekday: weekday, monthDay: monthDay,
        wifiOnly: wifiOnly, retain: retain).save();
      await BackgroundJobs.init();
      if (mounted) message('Jadwal tersimpan. Android dapat menunda proses latar belakang.');
    } catch (e) { if (mounted) message('Gagal menyimpan jadwal: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> connect() async {
    setState(() => busy = true);
    try {
      final result = await DriveBackupService.connect(clientId.text.trim());
      if (mounted) message('Google Drive tersambung: $result');
      await load();
    } catch (e) { if (mounted) message('Gagal menghubungkan Google: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> backupNow() async {
    setState(() => busy = true);
    try {
      final name = await DriveBackupService.backupNow();
      if (mounted) message('Backup berhasil dikirim ke Google Drive: $name');
    } catch (e) { if (mounted) message('Backup gagal: $e'); }
    finally { await load(); if (mounted) setState(() => busy = false); }
  }

  Future<void> disconnect() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Putuskan Google Drive?'),
      content: const Text('Jadwal otomatis dimatikan. File backup yang sudah ada di Drive tidak dihapus.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Putuskan'))]));
    if (confirm != true) return;
    setState(() => busy = true);
    try {
      await DriveBackupService.disconnect();
      await BackgroundJobs.init();
      await load();
    } catch (e) { if (mounted) message('Tidak dapat memutus akun: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  void message(String text) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Google Drive & Backup')),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [Icon(Icons.cloud_done_rounded, color: Color(0xFF1677D8)),
          SizedBox(width: 10), Expanded(child: Text('AGAN PONSEL • Cadangan Cloud',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 12),
        Text(email.isEmpty ? 'Belum tersambung ke akun Google' : 'Akun: $email'),
        const SizedBox(height: 13),
        TextField(controller: clientId, enabled: !busy && email.isEmpty,
          decoration: const InputDecoration(border: OutlineInputBorder(),
            labelText: 'Google OAuth Web Client ID',
            helperText: 'Daftarkan juga OAuth Android (package + SHA-1) di Google Cloud.'),
          maxLines: 2),
        const SizedBox(height: 12),
        if (email.isEmpty) FilledButton.icon(
          onPressed: busy ? null : connect, icon: const Icon(Icons.login_rounded),
          label: const Text('Hubungkan Akun Google'))
        else OutlinedButton.icon(onPressed: busy ? null : disconnect,
          icon: const Icon(Icons.link_off), label: const Text('Putuskan Akun')),
        const SizedBox(height: 10),
        const Text('Izin hanya drive.file: aplikasi dapat membuat/mengelola '
          'file yang dibuat AGAN PONSEL. Pengaturan OAuth Google Cloud '
          'harus selesai agar login berfungsi.', style: TextStyle(fontSize: 12)),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        SwitchListTile(value: enabled, onChanged: busy ? null : (v) => setState(() => enabled = v),
          title: const Text('Backup otomatis'),
          subtitle: const Text('Membutuhkan koneksi internet dan izin Google Drive')),
        const Divider(),
        DropdownButtonFormField<String>(initialValue: frequency,
          decoration: const InputDecoration(labelText: 'Pengulangan'),
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Setiap hari')),
            DropdownMenuItem(value: 'weekly', child: Text('Setiap minggu')),
            DropdownMenuItem(value: 'monthly', child: Text('Setiap bulan')),
          ], onChanged: busy ? null : (v) => setState(() => frequency = v ?? frequency)),
        if (frequency == 'weekly') DropdownButtonFormField<int>(initialValue: weekday,
          decoration: const InputDecoration(labelText: 'Hari backup'),
          items: List.generate(7, (i) => DropdownMenuItem(value: i + 1,
            child: Text(const ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'][i]))),
          onChanged: (v) => setState(() => weekday = v ?? weekday)),
        if (frequency == 'monthly') DropdownButtonFormField<int>(initialValue: monthDay,
          decoration: const InputDecoration(labelText: 'Tanggal setiap bulan (1–28)'),
          items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
          onChanged: (v) => setState(() => monthDay = v ?? monthDay)),
        ListTile(title: const Text('Jam target backup'),
          subtitle: Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} waktu HP'),
          trailing: const Icon(Icons.schedule_rounded),
          onTap: busy ? null : () async {
            final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: hour, minute: minute));
            if (time != null && mounted) setState(() { hour = time.hour; minute = time.minute; });
          }),
        SwitchListTile(value: wifiOnly, title: const Text('Hanya Wi-Fi'),
          onChanged: busy ? null : (v) => setState(() => wifiOnly = v)),
        DropdownButtonFormField<int>(initialValue: retain,
          decoration: const InputDecoration(labelText: 'Simpan berapa backup terakhir?'),
          items: const [7,14,30].map((v) => DropdownMenuItem(value: v, child: Text('$v file'))).toList(),
          onChanged: busy ? null : (v) => setState(() => retain = v ?? retain)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: busy ? null : save,
          icon: const Icon(Icons.save_rounded), label: const Text('Simpan Jadwal')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: busy || email.isEmpty ? null : backupNow,
          icon: const Icon(Icons.cloud_upload_rounded), label: const Text('Backup ke Drive Sekarang')),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Status Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Text('Terakhir berhasil: ${lastOk.isEmpty ? 'Belum pernah' : lastOk}'),
        if (lastName.isNotEmpty) Text('File: $lastName'),
        if (lastError.isNotEmpty) Text('Error terakhir: $lastError',
          style: const TextStyle(color: Color(0xFFB23737))),
        const SizedBox(height: 12),
        const Text('Data backup adalah file JSON yang belum dienkripsi. '
          'Simpan di akun Google pribadi yang terlindungi. Android bisa '
          'menunda tugas latar belakang dan akun mungkin perlu diotorisasi ulang.',
          style: TextStyle(fontSize: 12)),
      ]))),
    ]),
  );
}
