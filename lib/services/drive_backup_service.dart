import 'dart:convert';
import 'dart:math';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';

/// Uses the narrow drive.file scope. No Drive password, refresh token or
/// OAuth secret is stored in SharedPreferences; Google Play Services owns auth.
class DriveBackupConfig {
  final bool enabled;
  final String frequency;
  final int hour;
  final int minute;
  final int weekday;
  final int monthDay;
  final bool wifiOnly;
  final int retain;
  const DriveBackupConfig({this.enabled = false, this.frequency = 'daily',
    this.hour = 2, this.minute = 0, this.weekday = 1, this.monthDay = 1,
    this.wifiOnly = true, this.retain = 7});

  static Future<DriveBackupConfig> load() async {
    final p = await SharedPreferences.getInstance();
    return DriveBackupConfig(
      enabled: p.getBool('agan_drive_enabled') ?? false,
      frequency: p.getString('agan_drive_frequency') ?? 'daily',
      hour: p.getInt('agan_drive_hour') ?? 2,
      minute: p.getInt('agan_drive_minute') ?? 0,
      weekday: p.getInt('agan_drive_weekday') ?? 1,
      monthDay: p.getInt('agan_drive_month_day') ?? 1,
      wifiOnly: p.getBool('agan_drive_wifi_only') ?? true,
      retain: p.getInt('agan_drive_retain') ?? 7,
    );
  }

  Future<void> save() async {
    if (!['daily', 'weekly', 'monthly'].contains(frequency) ||
        hour < 0 || hour > 23 || minute < 0 || minute > 59 ||
        weekday < 1 || weekday > 7 || monthDay < 1 || monthDay > 28 ||
        ![7, 14, 30].contains(retain)) {
      throw const FormatException('Jadwal backup tidak valid');
    }
    final p = await SharedPreferences.getInstance();
    await p.setBool('agan_drive_enabled', enabled);
    await p.setString('agan_drive_frequency', frequency);
    await p.setInt('agan_drive_hour', hour);
    await p.setInt('agan_drive_minute', minute);
    await p.setInt('agan_drive_weekday', weekday);
    await p.setInt('agan_drive_month_day', monthDay);
    await p.setBool('agan_drive_wifi_only', wifiOnly);
    await p.setInt('agan_drive_retain', retain);
  }

  /// Last scheduled slot that must already have elapsed (device local time).
  DateTime scheduledSlot(DateTime now) {
    if (frequency == 'weekly') {
      final today = DateTime(now.year, now.month, now.day, hour, minute);
      final last = today.subtract(Duration(days: (today.weekday - weekday + 7) % 7));
      return last.isAfter(now) ? last.subtract(const Duration(days: 7)) : last;
    }
    if (frequency == 'monthly') {
      var slot = DateTime(now.year, now.month, monthDay, hour, minute);
      if (slot.isAfter(now)) {
        slot = DateTime(now.year, now.month - 1, monthDay, hour, minute);
      }
      return slot;
    }
    final slot = DateTime(now.year, now.month, now.day, hour, minute);
    return slot.isAfter(now) ? slot.subtract(const Duration(days: 1)) : slot;
  }

  bool due(DateTime now, DateTime? lastSuccess) {
    if (!enabled) return false;
    final slot = scheduledSlot(now);
    return lastSuccess == null || lastSuccess.isBefore(slot);
  }
}

class DriveBackupService {
  DriveBackupService._();
  static const scopes = <String>['https://www.googleapis.com/auth/drive.file'];
  static const _folderName = 'AGAN PONSEL Backups';
  static bool _uploading = false;
  static Future<void>? _googleInitialization;

  static Future<void> _initializeGoogle() async {
    final p = await SharedPreferences.getInstance();
    final id = (p.getString('agan_drive_web_client_id') ?? '').trim();
    if (id.isEmpty) {
      throw StateError('Isi OAuth Web Client ID di Pengaturan Google Drive.');
    }
    _googleInitialization ??= GoogleSignIn.instance.initialize(serverClientId: id);
    await _googleInitialization;
  }

  static Future<String> connect(String clientId) async {
    if (!clientId.trim().endsWith('.apps.googleusercontent.com')) {
      throw const FormatException('OAuth Web Client ID tidak valid');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('agan_drive_web_client_id', clientId.trim());
    await _initializeGoogle();
    final account = await GoogleSignIn.instance.authenticate();
    await account.authorizationClient.authorizeScopes(scopes);
    await p.setString('agan_drive_email', account.email);
    return account.email;
  }

  static Future<void> disconnect() async {
    await GoogleSignIn.instance.signOut();
    final p = await SharedPreferences.getInstance();
    await p.setBool('agan_drive_enabled', false);
    await p.remove('agan_drive_email');
    await p.remove('agan_drive_last_error');
  }

  static Future<(String, String)> _cachedAuthorization() async {
    await _initializeGoogle();
    // Background workers must never open a consent screen; if a cached account
    // or grant cannot be obtained the status will ask for reconnection in UI.
    final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account == null) throw StateError('Akun Google perlu disambungkan ulang.');
    final auth = await account.authorizationClient.authorizationForScopes(scopes);
    if (auth == null) {
      throw StateError('Izin Drive perlu diberikan ulang melalui tombol Hubungkan.');
    }
    return (account.email, auth.accessToken);
  }

  static Future<http.Response> _authorizedPost(Uri uri, String token,
      List<int> bytes, String contentType) {
    return http.post(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': contentType,
    }, body: bytes).timeout(const Duration(seconds: 90));
  }

  static void _assertSuccess(http.Response result, {String action = 'Google Drive'}) {
    if (result.statusCode < 200 || result.statusCode >= 300) {
      // Do not echo remote response: it can contain identifiable data.
      if (result.statusCode == 401 || result.statusCode == 403) {
        throw StateError('Izin Google Drive kedaluwarsa/ditolak. Sambungkan ulang akun.');
      }
      throw StateError('$action gagal (HTTP ${result.statusCode}).');
    }
  }

  static Future<String> _folderId(String email, String token) async {
    final p = await SharedPreferences.getInstance();
    final accountKey = base64Url.encode(utf8.encode(email)).replaceAll('=', '');
    final key = 'agan_drive_folder_$accountKey';
    final cached = p.getString(key);
    if (cached != null && cached.isNotEmpty) return cached;
    final result = await _authorizedPost(
      Uri.parse('https://www.googleapis.com/drive/v3/files?fields=id,name'),
      token,
      utf8.encode(jsonEncode({'name': _folderName,
        'mimeType': 'application/vnd.google-apps.folder'})),
      'application/json; charset=UTF-8');
    _assertSuccess(result, action: 'Membuat folder Drive');
    final id = jsonDecode(result.body)['id'] as String?;
    if (id == null || id.isEmpty) throw StateError('ID folder Drive kosong');
    await p.setString(key, id);
    return id;
  }

  static Future<String> _upload(String token, String folderId, List<int> bytes) async {
    final safeDate = DateTime.now().toIso8601String().replaceAll(':', '-');
    final name = 'AGAN-PONSEL-$safeDate.json';
    final boundary = 'AGAN${Random.secure().nextInt(1 << 32).toRadixString(16)}';
    final metadata = jsonEncode({'name': name, 'parents': [folderId],
      'mimeType': 'application/json'});
    final head = utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'
      '$metadata\r\n'
      '--$boundary\r\nContent-Type: application/json\r\n\r\n');
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    final body = <int>[...head, ...bytes, ...tail];
    final result = await _authorizedPost(Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name'),
      token, body, 'multipart/related; boundary=$boundary');
    _assertSuccess(result, action: 'Upload file backup');
    final id = jsonDecode(result.body)['id'] as String?;
    if (id == null || id.isEmpty) throw StateError('Drive tidak mengembalikan ID file');
    return name;
  }

  static Future<void> _prune(String folderId, String token, int retain) async {
    final q = "'$folderId' in parents and trashed = false";
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': q, 'fields': 'nextPageToken,files(id,name,createdTime)',
      'pageSize': '100', 'orderBy': 'createdTime desc',
    });
    final result = await http.get(uri, headers: {'Authorization': 'Bearer $token'})
      .timeout(const Duration(seconds: 30));
    _assertSuccess(result, action: 'Memeriksa retensi backup');
    final files = (jsonDecode(result.body)['files'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .where((x) => (x['name'] as String? ?? '').startsWith('AGAN-PONSEL-'))
      .toList();
    for (final old in files.skip(retain)) {
      final id = old['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final deleted = await http.delete(
        Uri.https('www.googleapis.com', '/drive/v3/files/$id'),
        headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      _assertSuccess(deleted, action: 'Menghapus backup lama');
    }
  }

  static Future<String> backupNow() async {
    if (_uploading) throw StateError('Backup sedang berjalan');
    _uploading = true;
    final p = await SharedPreferences.getInstance();
    try {
      final (email, token) = await _cachedAuthorization();
      final data = await BackupService.createBackupBytes();
      final folder = await _folderId(email, token);
      final name = await _upload(token, folder, data);
      await p.setString('agan_drive_last_ok', DateTime.now().toIso8601String());
      await p.setString('agan_drive_last_name', name);
      await p.remove('agan_drive_last_error');
      // A cleanup problem must never conceal the success of the uploaded file.
      try {
        await _prune(folder, token, (await DriveBackupConfig.load()).retain);
      } catch (_) { /* Keep old backups if Drive refused cleanup. */ }
      return name;
    } catch (e) {
      await p.setString('agan_drive_last_error', e.toString());
      rethrow;
    } finally {
      _uploading = false;
    }
  }

  static Future<bool> runIfDue() async {
    final config = await DriveBackupConfig.load();
    final p = await SharedPreferences.getInstance();
    final lastText = p.getString('agan_drive_last_ok');
    final last = lastText == null ? null : DateTime.tryParse(lastText);
    if (!config.due(DateTime.now(), last)) return false;
    await backupNow();
    return true;
  }
}
