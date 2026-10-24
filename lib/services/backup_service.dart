import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database.dart';
import 'product_photos.dart';
import 'store_brand.dart';

/// A portable, integrity-checked snapshot of the on-device SQLite database.
/// Backups are NOT encrypted. Keep them in a private, trusted location.
class BackupService {
  BackupService._();

  static const int maxBackupBytes = 50 * 1024 * 1024;
  static const tables = <String>[
    'products', 'sales', 'services', 'customers', 'expenses',
    'expense_categories', 'expense_audit',
    'digital_transactions', 'receipts', 'receipt_items',
    'stock_movements', 'service_events', 'cash_adjustments', 'store_notes', 'receivables', 'receivable_payments', 'agent_activity', 'receivable_items', 'receivable_receipt_events',
    'receivable_payment_edits', 'receivable_bon_events',
    'suppliers', 'restock_orders', 'restock_order_items',
  ];
  static const requiredTables = <String>{
    'products', 'sales', 'services', 'customers', 'expenses',
    'digital_transactions', 'receipts', 'receipt_items', 'stock_movements',
  };
  static const profileKeys = <String>[
    'local_owner_name', 'local_owner_phone', 'local_owner_email',
    'local_shop_name', 'local_shop_address', 'local_receipt_footer',
    'daily_sales_target', 'app_template_style', 'app_font_family', 'reminder_message_template',
    'expense_budget_settings',
    'receivable_receipt_template',
  ];

  static Future<Map<String, dynamic>> _snapshot() async {
    final db = await AppDatabase.instance;
    final records = await db.transaction<Map<String, dynamic>>((txn) async {
      final output = <String, dynamic>{};
      for (final table in tables) {
        output[table] = await txn.query(table, orderBy: 'id ASC');
      }
      return output;
    });
    // Include locally stored product photos in the portable backup.
    final media = <String, String>{};
    final productRows = records['products'] as List<Map<String, Object?>>;
    for (final item in productRows) {
      final name = item['photo_file'] as String? ?? '';
      if (name.isEmpty || media.containsKey(name)) continue;
      final file = await ProductPhotos.file(name);
      if (file == null) throw StateError('Foto produk tidak ditemukan: $name');
      final data = await file.readAsBytes();
      if (data.length > 3 * 1024 * 1024) throw StateError('Foto terlalu besar: $name');
      media[name] = base64Encode(data);
    }
    final prefs = await SharedPreferences.getInstance();
    final profile = <String, String>{};
    for (final key in profileKeys) {
      final value = prefs.getString(key);
      if (value != null) profile[key] = value;
    }
    final logoBytes = await StoreBrand.backupBytes();
    return <String, dynamic>{
      'format': 'agan-ponsel-sqlite-json',
      'formatVersion': 3,
      'databaseVersion': 14,
      'createdAt': DateTime.now().toIso8601String(),
      'tables': records,
      'media': media,
      'logo': logoBytes == null ? null : base64Encode(logoBytes),
      'profile': profile,
    };
  }

  /// Same SHA-256 envelope as manual export, without opening Android's file UI.
  /// Safe for background jobs; this method never restores or deletes records.
  static Future<Uint8List> createBackupBytes() async {
    final payload = await _snapshot();
    final payloadJson = jsonEncode(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
      'sha256': sha256.convert(utf8.encode(payloadJson)).toString(),
      'payload': payload,
    })));
    if (bytes.lengthInBytes > maxBackupBytes) {
      throw StateError('Backup lebih dari 50 MB; ekspor otomatis dibatalkan.');
    }
    return bytes;
  }

  static Future<Uri?> exportBackup() async {
    final payload = await _snapshot();
    final payloadJson = jsonEncode(payload);
    final envelope = jsonEncode({
      'sha256': sha256.convert(utf8.encode(payloadJson)).toString(),
      'payload': payload,
    });
    final bytes = Uint8List.fromList(utf8.encode(envelope));
    if (bytes.lengthInBytes > maxBackupBytes) {
      throw StateError('Ukuran backup lebih dari 50 MB. Hubungi pengembang untuk ekspor bertahap.');
    }
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return FilePicker.saveFile(
      dialogTitle: 'Simpan Backup AGAN PONSEL',
      fileName: 'agan-ponsel-backup-$date.json',
      bytes: bytes,
    );
  }

  /// Reads + fully validates the file BEFORE the existing database is touched.
  /// The UI must require explicit user confirmation prior to calling this.
  static Future<BackupPreview?> chooseBackup() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.lengthInBytes > maxBackupBytes) {
      throw FormatException('File kosong atau lebih dari 50 MB');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('Format backup tidak dikenal');
    final payload = decoded['payload'];
    final hash = decoded['sha256'];
    if (payload is! Map<String, dynamic> || hash is! String) {
      throw const FormatException('Metadata backup tidak lengkap');
    }
    if (sha256.convert(utf8.encode(jsonEncode(payload))).toString() != hash) {
      throw const FormatException('Integritas backup tidak cocok (SHA-256)');
    }
    if (payload['format'] != 'agan-ponsel-sqlite-json' || ![1, 2, 3].contains(payload['formatVersion'])) {
      throw const FormatException('Format atau versi backup tidak didukung');
    }
    if (![4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14].contains(payload['databaseVersion'])) {
      throw const FormatException('Backup memerlukan versi database yang berbeda');
    }
    final rawTables = payload['tables'];
    if (rawTables is! Map<String, dynamic> || !rawTables.keys.toSet().containsAll(requiredTables)) {
      throw const FormatException('Tabel penting pada backup tidak lengkap');
    }
    if (!tables.toSet().containsAll(rawTables.keys)) {
      throw const FormatException('Backup mengandung tabel tidak dikenal');
    }
    final validated = <String, List<Map<String, Object?>>>{};
    final db = await AppDatabase.instance;
    for (final name in tables) {
      final raw = rawTables[name] ?? <dynamic>[];
      if (raw is! List) throw FormatException('Data $name tidak berbentuk daftar');
      final allowed = (await db.rawQuery('PRAGMA table_info($name)'))
          .map((row) => row['name'] as String).toSet();
      if (allowed.isEmpty) throw FormatException('Tabel $name tidak ada di perangkat');
      final rows = <Map<String, Object?>>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic>) throw FormatException('Baris $name tidak valid');
        if (!allowed.containsAll(item.keys)) throw FormatException('Kolom $name tidak dikenal');
        final data = <String, Object?>{};
        for (final entry in item.entries) {
          final value = entry.value;
          if (value != null && value is! String && value is! num) {
            throw FormatException('Tipe data $name tidak valid');
          }
          data[entry.key] = value;
        }
        rows.add(data);
      }
      validated[name] = rows;
    }
    final profile = <String, String>{};
    final rawProfile = payload['profile'];
    if (rawProfile != null) {
      if (rawProfile is! Map<String, dynamic>) throw const FormatException('Profil backup tidak valid');
      for (final key in profileKeys) {
        final value = rawProfile[key];
        if (value is String) profile[key] = value;
      }
    }
    final media = <String, List<int>>{};
    final rawMedia = payload['media'];
    if (rawMedia != null) {
      if (rawMedia is! Map<String, dynamic>) {
        throw const FormatException('Foto backup tidak valid');
      }
      int sum = 0;
      for (final record in rawMedia.entries) {
        final name = record.key;
        if (!ProductPhotos.validName(name) || record.value is! String) {
          throw FormatException('Nama atau format foto tidak aman: $name');
        }
        final bytes = base64Decode(record.value as String);
        sum += bytes.length;
        if (bytes.length > 3 * 1024 * 1024 || sum > 40 * 1024 * 1024) {
          throw const FormatException('Ukuran media backup terlalu besar');
        }
        media[name] = bytes;
      }
    }
    for (final row in validated['products'] ?? const <Map<String, Object?>>[]) {
      final filename = row['photo_file'] as String? ?? '';
      if (filename.isNotEmpty && !media.containsKey(filename)) {
        throw FormatException('File foto tidak lengkap: $filename');
      }
    }
    List<int>? logoBytes;
    final rawLogo = payload['logo'];
    if (rawLogo != null) {
      if (rawLogo is! String) throw const FormatException('Logo backup tidak valid');
      logoBytes = base64Decode(rawLogo);
      if (!StoreBrand.validBytes(logoBytes)) {
        throw const FormatException('Logo toko bukan JPG, PNG atau WebP yang valid');
      }
    }
    return BackupPreview(
      hasBranding: (payload['formatVersion'] as int) >= 3,
      logoBytes: logoBytes,
      filename: file.name,
      createdAt: '${payload['createdAt'] ?? '-'}',
      data: validated,
      profile: profile,
      media: media,
    );
  }

  static Future<void> restore(BackupPreview backup) async {
    final db = await AppDatabase.instance;
    final photoDirectory = await ProductPhotos.directory();
    final remapped = <String, String>{};
    final written = <File>[];
    try {
      // Stage files under NEW randomized names to avoid overwriting photos
      // referenced by the current database if the SQL transaction fails.
      final rng = Random.secure();
      for (final media in backup.media.entries) {
        final replacement = 'product_${DateTime.now().microsecondsSinceEpoch}_'
          '${rng.nextInt(0x7fffffff).toRadixString(36)}.jpg';
        final file = File(p.join(photoDirectory.path, replacement));
        await file.writeAsBytes(media.value, flush: true);
        remapped[media.key] = replacement;
        written.add(file);
      }
      await db.transaction((txn) async {
        // Delete dependents first; preserve schema & database version.
        for (final name in tables.reversed) { await txn.delete(name); }
        for (final name in tables) {
          for (final original in backup.data[name] ?? const <Map<String, Object?>>[]) {
            final row = Map<String, Object?>.from(original);
            if (name == 'products') {
              final oldName = row['photo_file'] as String? ?? '';
              if (oldName.isNotEmpty) row['photo_file'] = remapped[oldName];
            }
            await txn.insert(name, row, conflictAlgorithm: ConflictAlgorithm.abort);
          }
        }
        // Backup lama belum memiliki tanggal per item: gunakan tanggal piutang.
        await txn.rawUpdate('''UPDATE receivable_items SET entry_date =
          COALESCE((SELECT substr(created_at,1,10) FROM receivables
            WHERE receivables.id=receivable_items.receivable_id), strftime('%Y-%m-%d','now'))
          WHERE entry_date = '' OR entry_date IS NULL''');
      });
    } catch (_) {
      for (final file in written) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
    final prefs = await SharedPreferences.getInstance();
    for (final entry in backup.profile.entries) {
      await prefs.setString(entry.key, entry.value);
    }
    if (backup.hasBranding) {
      if (backup.logoBytes == null) {
        await StoreBrand.removeLogo();
      } else {
        await StoreBrand.restoreBytes(backup.logoBytes!);
      }
    }
  }

}

class BackupPreview {
  final bool hasBranding;
  final List<int>? logoBytes;
  final String filename;
  final String createdAt;
  final Map<String, List<Map<String, Object?>>> data;
  final Map<String, String> profile;
  final Map<String, List<int>> media;
  const BackupPreview({
    required this.hasBranding,
    required this.logoBytes,
    required this.filename,
    required this.createdAt,
    required this.data,
    required this.profile,
    required this.media,
  });
  int get count => data.values.fold<int>(0, (total, rows) => total + rows.length);
  int countOf(String table) => data[table]?.length ?? 0;
}
