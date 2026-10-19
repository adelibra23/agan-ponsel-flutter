import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database.dart';
import '../core/format.dart';
import 'receivables_service.dart';

/// Template disimpan per-perangkat, tanpa menyertakan data rahasia ke server.
enum ReceivableReceiptTemplate { orbit, white, midnight, emerald }

extension ReceiptTemplateLabel on ReceivableReceiptTemplate {
  String get label => switch (this) {
    ReceivableReceiptTemplate.orbit => 'Classic Blue',
    ReceivableReceiptTemplate.white => 'Clean White',
    ReceivableReceiptTemplate.midnight => 'Dark Premium',
    ReceivableReceiptTemplate.emerald => 'Agan Store Modern',
  };
}

/// Status berasal dari data pembayaran, bukan informasi yang bisa diedit manual.
String debtReceiptStatus(int amount, int paid) {
  if (amount <= 0 || paid >= amount) return 'LUNAS';
  if (paid > 0) return 'CICILAN';
  return 'BELUM LUNAS';
}

String debtReceiptNumber(int id) => 'AGP-${id.toString().padLeft(6, '0')}';

class ReceivableReceiptData {
  final Receivable receivable;
  final List<ReceivableLine> lines;
  final List<Map<String, Object?>> payments;
  final String shopName;
  final String address;
  final String shopPhone;
  final String footer;
  final String admin;

  const ReceivableReceiptData({
    required this.receivable,
    required this.lines,
    required this.payments,
    required this.shopName,
    required this.address,
    required this.shopPhone,
    required this.footer,
    required this.admin,
  });

  String get number => debtReceiptNumber(receivable.id);
  String get status => debtReceiptStatus(receivable.amount, receivable.paid);
}

class ReceivableReceiptService {
  ReceivableReceiptService._();
  static const preferenceKey = 'receivable_receipt_template';

  static Future<ReceivableReceiptTemplate> selectedTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(preferenceKey) ?? 'orbit';
    for (final template in ReceivableReceiptTemplate.values) {
      if (template.name == value) return template;
    }
    return ReceivableReceiptTemplate.orbit;
  }

  static Future<void> setTemplate(ReceivableReceiptTemplate value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, value.name);
  }

  /// Memuat data dalam satu transaksi baca agar total dan cicilan tidak
  /// berubah di tengah proses pembuatan nota.
  static Future<ReceivableReceiptData> load(int id) async {
    final db = await AppDatabase.instance;
    final collected = await db.transaction<({Receivable debt, List<ReceivableLine> lines, List<Map<String, Object?>> payments})>((txn) async {
      final rows = await txn.rawQuery('''
        SELECT r.*, COALESCE((SELECT SUM(amount) FROM receivable_payments
        WHERE receivable_id=r.id), 0) AS paid
        FROM receivables r WHERE r.id=? LIMIT 1
      ''', [id]);
      if (rows.isEmpty) throw StateError('Piutang tidak ditemukan');
      final itemRows = await txn.query('receivable_items', where: 'receivable_id=?',
        whereArgs: [id], orderBy: 'sort_order ASC, id ASC');
      final payRows = await txn.query('receivable_payments', where: 'receivable_id=?',
        whereArgs: [id], orderBy: 'paid_at DESC, id DESC');
      return (debt: Receivable.fromRow(rows.single),
        lines: itemRows.map(ReceivableLine.fromRow).toList(),
        payments: payRows);
    });
    final prefs = await SharedPreferences.getInstance();
    return ReceivableReceiptData(
      receivable: collected.debt,
      lines: collected.lines,
      payments: collected.payments,
      shopName: prefs.getString('local_shop_name') ?? 'AGAN PONSEL',
      address: prefs.getString('local_shop_address') ?? '',
      shopPhone: prefs.getString('local_owner_phone') ?? '',
      footer: prefs.getString('local_receipt_footer') ?? 'Terima kasih telah mempercayai AGAN PONSEL.',
      admin: prefs.getString('local_owner_name') ?? 'Admin Toko',
    );
  }

  /// Catat aksi yang BENAR-BENAR dilakukan oleh aplikasi. Bukan bukti bahwa
  /// kertas keluar atau pesan sudah diterima pelanggan.
  static Future<void> logAction(int receivableId, String action,
      ReceivableReceiptTemplate template, {String destination = ''}) async {
    if (!const {'print_dispatched', 'image_saved', 'share_sheet_opened'}.contains(action)) {
      throw ArgumentError('Aksi nota tidak dikenal');
    }
    final db = await AppDatabase.instance;
    await db.insert('receivable_receipt_events', {
      'receivable_id': receivableId,
      'action': action,
      'destination': destination.trim(),
      'template': template.name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, Object?>>> history(int id) async =>
    (await AppDatabase.instance).query('receivable_receipt_events',
      where: 'receivable_id=?', whereArgs: [id], orderBy: 'id DESC', limit: 30);
}

String receivableThermalText(ReceivableReceiptData data, {int chars = 32}) {
  if (chars < 24) throw ArgumentError('Lebar printer minimal 24 karakter');
  String safe(String source) => source
    .replaceAll(RegExp(r'[\r\t]'), ' ')
    .replaceAll(RegExp(r'[^\x20-\x7e\n]'), '?');
  String center(String source) {
    final value = safe(source);
    return value.length >= chars ? value : '${' ' * ((chars - value.length) ~/ 2)}$value';
  }
  String pair(String left, String right) {
    final l = safe(left), r = safe(right);
    final free = chars - l.length - r.length;
    return free > 0 ? '$l${' ' * free}$r' : '$l\n${' ' * (chars - r.length > 0 ? chars - r.length : 0)}$r';
  }
  String wrap(String source) {
    final words = safe(source).trim().split(RegExp(r'\s+'));
    final rows = <String>[];
    var line = '';
    for (final word in words) {
      if (line.isNotEmpty && line.length + word.length + 1 > chars) {
        rows.add(line); line = '';
      }
      if (word.length > chars) {
        if (line.isNotEmpty) { rows.add(line); line = ''; }
        for (var i = 0; i < word.length; i += chars) {
          rows.add(word.substring(i, i + chars < word.length ? i + chars : word.length));
        }
      } else {
        line = line.isEmpty ? word : '$line $word';
      }
    }
    if (line.isNotEmpty) rows.add(line);
    return rows.join('\n');
  }

  final r = data.receivable;
  final b = StringBuffer()
    ..writeln(center(data.shopName.toUpperCase()))
    ..writeln(center('NOTA PIUTANG'))
    ..writeln('=' * chars)
    ..writeln('No    : ${data.number}')
    ..writeln('Dibuat: ${dateLabel(r.createdAt)}')
    ..writeln('JTempo: ${dateLabel(r.dueDate)}')
    ..writeln(wrap('Nama  : ${r.customer}'));
  if (r.phone.trim().isNotEmpty) b.writeln(wrap('HP    : ${r.phone}'));
  b..writeln('-' * chars)
    ..writeln('RINCIAN TAGIHAN');
  if (data.lines.isEmpty) {
    b..writeln(wrap(r.description))
      ..writeln(pair('1 x ${rupiah(r.amount)}', rupiah(r.amount)));
  } else {
    for (final line in data.lines) {
      b..writeln(wrap(line.description))
        ..writeln(pair('${line.qty} x ${rupiah(line.unitPrice)}', rupiah(line.total)));
    }
  }
  b..writeln('-' * chars)
    ..writeln(pair('TOTAL', rupiah(r.amount)))
    ..writeln(pair('DIBAYAR', rupiah(r.paid)))
    ..writeln(pair('SISA', rupiah(r.remaining)))
    ..writeln('-' * chars)
    ..writeln(center(data.status))
    ..writeln('-' * chars);
  if (r.notes.isNotEmpty) b.writeln(wrap('Catatan: ${r.notes}'));
  if (data.address.trim().isNotEmpty) b.writeln(wrap(data.address));
  if (data.shopPhone.trim().isNotEmpty) b.writeln(wrap('Tel: ${data.shopPhone}'));
  b..writeln(center('Admin: ${data.admin}'))
    ..writeln(wrap(data.footer))
    ..writeln(center('Simpan nota ini.'));
  return b.toString();
}
