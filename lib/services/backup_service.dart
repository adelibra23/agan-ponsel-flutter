import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database.dart';

/// A portable, integrity-checked snapshot of the on-device SQLite database.
/// Backups are NOT encrypted. Keep them in a private, trusted location.
class BackupService {
  BackupService._();

  static const int maxBackupBytes = 50 * 1024 * 1024;
  static const tables = <String>[
    'products', 'sales', 'services', 'customers', 'expenses',
    'digital_transactions', 'receipts', 'receipt_items',
    'stock_movements', 'service_events',
  ];
  static const requiredTables = <String>{
    'products', 'sales', 'services', 'customers', 'expenses',
    'digital_transactions', 'receipts', 'receipt_items', 'stock_movements',
  };
  static const profileKeys = <String>[
    'local_owner_name', 'local_owner_phone', 'local_owner_email',
    'local_shop_name', 'local_shop_address', 'local_receipt_footer',
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
    final prefs = await SharedPreferences.getInstance();
    final profile = <String, String>{};
    for (final key in profileKeys) {
      final value = prefs.getString(key);
      if (value != null) profile[key] = value;
    }
    return <String, dynamic>{
      'format': 'agan-ponsel-sqlite-json',
      'formatVersion': 1,
      'databaseVersion': 4,
      'createdAt': DateTime.now().toIso8601String(),
      'tables': records,
      'profile': profile,
    };
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
    if (payload['format'] != 'agan-ponsel-sqlite-json' || payload['formatVersion'] != 1) {
      throw const FormatException('Format atau versi backup tidak didukung');
    }
    if (payload['databaseVersion'] != 4) {
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
    return BackupPreview(
      filename: file.name,
      createdAt: '${payload['createdAt'] ?? '-'}',
      data: validated,
      profile: profile,
    );
  }

  static Future<void> restore(BackupPreview backup) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      // Delete dependents first. Never DROP tables or schema/migration metadata.
      for (final name in tables.reversed) {
        await txn.delete(name);
      }
      // Parents first. All inserts occur in one atomic SQLite transaction.
      for (final name in tables) {
        for (final row in backup.data[name] ?? const <Map<String, Object?>>[]) {
          await txn.insert(name, row, conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }
    });
    final prefs = await SharedPreferences.getInstance();
    for (final entry in backup.profile.entries) {
      await prefs.setString(entry.key, entry.value);
    }
  }
}

class BackupPreview {
  final String filename;
  final String createdAt;
  final Map<String, List<Map<String, Object?>>> data;
  final Map<String, String> profile;
  const BackupPreview({
    required this.filename,
    required this.createdAt,
    required this.data,
    required this.profile,
  });
  int get count => data.values.fold<int>(0, (total, rows) => total + rows.length);
  int countOf(String table) => data[table]?.length ?? 0;
}
