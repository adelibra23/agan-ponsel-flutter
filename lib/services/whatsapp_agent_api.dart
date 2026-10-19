import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Admin-only companion to a separately hosted WhatsApp Business Cloud API
/// webhook. Tokens and API secrets must never be bundled into Android assets.
class WhatsappAgentApi {
  WhatsappAgentApi._();
  static final _storage = FlutterSecureStorage();
  static const _urlKey = 'agan_wa_gateway_url';
  static const _adminKey = 'agan_wa_gateway_admin_token';

  static Future<String> savedUrl() async =>
      await _storage.read(key: _urlKey) ?? '';

  static Future<bool> hasAdminToken() async =>
      (await _storage.read(key: _adminKey) ?? '').isNotEmpty;

  static Uri _validateUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException('Gunakan URL server HTTPS yang valid, tanpa query atau password');
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/$'), ''));
  }

  static Future<void> save(String url, String? token) async {
    final base = _validateUrl(url);
    if (token != null && token.trim().isNotEmpty && token.trim().length < 24) {
      throw const FormatException('Token admin terlalu pendek (minimal 24 karakter)');
    }
    await _storage.write(key: _urlKey, value: base.toString());
    if (token != null && token.trim().isNotEmpty) {
      await _storage.write(key: _adminKey, value: token.trim());
    }
  }

  static Future<void> disconnect() async {
    // Disconnecting Android admin does not change the server's running mode.
    await _storage.delete(key: _adminKey);
    await _storage.delete(key: _urlKey);
  }

  static Future<Map<String, dynamic>> _request(String path,
      {Map<String, Object?>? body}) async {
    final url = await savedUrl();
    final token = await _storage.read(key: _adminKey);
    if (url.isEmpty || token == null || token.isEmpty) {
      throw StateError('Simpan alamat HTTPS dan token admin server terlebih dahulu');
    }
    final base = _validateUrl(url);
    final endpoint = base.replace(path: '${base.path}$path');
    final client = http.Client();
    try {
      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = (body == null
              ? client.get(endpoint, headers: headers)
              : client.post(endpoint, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 12));
      final result = await response;
      if (result.statusCode == 401 || result.statusCode == 403) {
        throw StateError('Token admin ditolak oleh server WhatsApp');
      }
      if (result.statusCode >= 400) {
        throw StateError('Server menolak permintaan (HTTP ${result.statusCode})');
      }
      final parsed = jsonDecode(utf8.decode(result.bodyBytes));
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Respons server WhatsApp tidak valid');
      }
      return parsed;
    } on TimeoutException {
      throw StateError('Server tidak merespons. Periksa HTTPS dan hosting.');
    } on http.ClientException {
      throw StateError('Server tidak dapat dihubungi. Periksa jaringan.');
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> status() => _request('/admin/status');
  static Future<Map<String, dynamic>> setEnabled(bool enabled) =>
      _request('/admin/agent', body: {'enabled': enabled});
  static Future<Map<String, dynamic>> handoff(String threadId, bool paused) {
    if (!RegExp(r'^[a-f0-9]{16}$').hasMatch(threadId)) {
      throw const FormatException('ID percakapan tidak valid');
    }
    return _request('/admin/threads/$threadId/handoff', body: {'paused': paused});
  }
}
