import 'package:flutter/material.dart';
import '../../services/background_jobs.dart';
import '../../services/debt_alarm_service.dart';

class DebtAlarmSettingsScreen extends StatefulWidget {
  const DebtAlarmSettingsScreen({super.key});
  @override
  State<DebtAlarmSettingsScreen> createState() => _DebtAlarmSettingsScreenState();
}

class _DebtAlarmSettingsScreenState extends State<DebtAlarmSettingsScreen> {
  bool busy = false, loading = true, enabled = false;
  bool three = true, one = true, today = true, overdue = true;
  int hour = 9, minute = 0;

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final c = await DebtAlarmConfig.load();
    if (mounted) setState(() {
      enabled = c.enabled; hour = c.hour; minute = c.minute;
      three = c.threeDays; one = c.oneDay;
      today = c.dueToday; overdue = c.overdue;
      loading = false;
    });
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await DebtAlarmConfig(enabled: enabled, hour: hour, minute: minute,
        threeDays: three, oneDay: one, dueToday: today, overdue: overdue).save();
      if (enabled) await DebtAlarmService.initialize(askPermission: true);
      await BackgroundJobs.init();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Alarm disimpan. Android dapat menunda notifikasi latar belakang.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pengaturan alarm gagal: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> checkNow() async {
    setState(() => busy = true);
    try {
      final shown = await DebtAlarmService.checkAndNotify(force: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(shown ? 'Notifikasi pengingat dicoba dikirim' :
          'Tidak ada tagihan yang memenuhi pengaturan pengingat.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pengingat gagal: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alarm Jatuh Tempo')),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      Card(child: Column(children: [
        SwitchListTile(value: enabled, onChanged: busy ? null : (v) => setState(() => enabled = v),
          secondary: const Icon(Icons.notifications_active_rounded),
          title: const Text('Aktifkan alarm piutang'),
          subtitle: const Text('Bunyi dan getar melalui notifikasi Android')),
        ListTile(title: const Text('Jam target pengingat'),
          subtitle: Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} waktu HP'),
          trailing: const Icon(Icons.access_alarm_rounded),
          onTap: busy ? null : () async {
            final time = await showTimePicker(context: context,
              initialTime: TimeOfDay(hour: hour, minute: minute));
            if (time != null && mounted) setState(() { hour = time.hour; minute = time.minute; });
          }),
        const Divider(),
        CheckboxListTile(value: three, title: const Text('3 hari sebelum jatuh tempo'),
          onChanged: (v) => setState(() => three = v ?? three)),
        CheckboxListTile(value: one, title: const Text('1 hari sebelum jatuh tempo'),
          onChanged: (v) => setState(() => one = v ?? one)),
        CheckboxListTile(value: today, title: const Text('Pada hari jatuh tempo'),
          onChanged: (v) => setState(() => today = v ?? today)),
        CheckboxListTile(value: overdue, title: const Text('Tagihan yang terlambat'),
          onChanged: (v) => setState(() => overdue = v ?? overdue)),
        Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: busy ? null : save, icon: const Icon(Icons.save_rounded),
            label: const Text('Simpan & Izinkan Notifikasi'))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: busy || !enabled ? null : checkNow,
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Periksa Tagihan Sekarang'))),
        ])),
      ])),
      const SizedBox(height: 13),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text(
        'Alarm hanya untuk piutang yang masih memiliki sisa tagihan. '
        'Ringkasan dikirim maksimal sekali per hari. Jam tidak selalu '
        'tepat karena pembatasan baterai Android. Izin notifikasi harus aktif; '
        'periksa Pengaturan Android bila tidak ada bunyi.'))),
    ]),
  );
}
