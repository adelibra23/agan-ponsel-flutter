import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// API keys belong to the owner of this phone; they are never bundled into the APK,
/// logged, exported by app backup, or shared with other installations.
class AiProvider {
  final String id;
  final String label;
  final String model;
  final String keyUrl;
  const AiProvider(this.id, this.label, this.model, this.keyUrl);
}

class AiProviders {
  static const all = <AiProvider>[
    AiProvider('openrouter', 'OpenRouter • Free Router', 'openrouter/free', 'https://openrouter.ai/keys'),
    AiProvider('gemini', 'Google Gemini', 'gemini-2.5-flash', 'https://aistudio.google.com/apikey'),
    AiProvider('groq', 'Groq Cloud', 'openai/gpt-oss-20b', 'https://console.groq.com/keys'),
  ];
  static AiProvider byId(String id) => all.firstWhere((p) => p.id == id,
    orElse: () => all.first);
}

class AiConfiguration {
  final String provider;
  final String model;
  final bool enabled;
  final bool shortAnswers;
  const AiConfiguration({required this.provider, required this.model,
    required this.enabled, required this.shortAnswers});
}

class AiGateway {
  AiGateway._();
  static final _vault = FlutterSecureStorage();
  static const _providerKey = 'agana_ai_provider';
  static const _enabledKey = 'agana_ai_enabled';
  static const _shortKey = 'agana_ai_short';
  static String _keySlot(String provider) => 'agana_secret_${AiProviders.byId(provider).id}';
  static String _modelSlot(String provider) => 'agana_model_${AiProviders.byId(provider).id}';

  static Future<AiConfiguration> load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = AiProviders.byId(prefs.getString(_providerKey) ?? 'openrouter');
    return AiConfiguration(provider: provider.id,
      model: prefs.getString(_modelSlot(provider.id)) ?? provider.model,
      enabled: prefs.getBool(_enabledKey) ?? false,
      shortAnswers: prefs.getBool(_shortKey) ?? true);
  }

  static Future<void> save({required String provider, required String model,
      required bool enabled, required bool shortAnswers, String? newApiKey}) async {
    final selected = AiProviders.byId(provider);
    final cleanedModel = model.trim();
    if (!RegExp(r'^[a-zA-Z0-9._:/-]{2,110}$').hasMatch(cleanedModel)) {
      throw const FormatException('Nama model tidak valid');
    }
    final prefs = await SharedPreferences.getInstance();
    if (newApiKey != null && newApiKey.trim().isNotEmpty) {
      await _vault.write(key: _keySlot(selected.id), value: newApiKey.trim());
    }
    if (enabled && !(await hasKey(selected.id))) {
      throw const FormatException('Simpan API key terlebih dahulu untuk mengaktifkan AI');
    }
    await prefs.setString(_providerKey, selected.id);
    await prefs.setString(_modelSlot(selected.id), cleanedModel);
    await prefs.setBool(_shortKey, shortAnswers);
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Reads the selected provider key from encrypted Android storage.
  /// Show it only in the owner's settings UI, obscured by default.
  static Future<String?> readStoredKey(String provider) =>
      _vault.read(key: _keySlot(provider));

  static Future<String> modelForProvider(String provider) async {
    final chosen = AiProviders.byId(provider);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelSlot(chosen.id)) ?? chosen.model;
  }

  static Future<bool> hasKey(String provider) async {
    final stored = await _vault.read(key: _keySlot(provider));
    return stored != null && stored.trim().isNotEmpty;
  }

  static Future<void> deleteKey(String provider) async {
    await _vault.delete(key: _keySlot(provider));
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_providerKey) ?? 'openrouter') == provider) {
      await prefs.setBool(_enabledKey, false);
    }
  }

  static const _system = '''Kamu AGANA, asisten aplikasi konter AGAN PONSEL.
Jawab dalam bahasa Indonesia dengan jelas dan ringkas. Kamu tidak memiliki akses langsung ke SQLite, isi rekening, pelanggan, saldo, service maupun piutang kecuali data ditulis secara eksplisit oleh pengguna dalam percakapan ini.
Jangan mengarang nominal, hasil pengecekan tagihan, transaksi, atau data toko. Untuk cek data toko, arahkan pengguna ke perintah AGANA lokal seperti "cek tagihan Budi", "stok menipis", "cek service Andi", atau "laporan hari ini".
Kamu tidak dapat menjalankan perubahan database lewat jawaban teks; pengguna harus menggunakan formulir atau kartu persetujuan di aplikasi. Jangan meminta API key, PIN, password atau data sensitif. Jangan mengklaim telah menyimpan sesuatu. Semua layanan API mungkin memiliki kuota atau biaya.''';

  /// Requests only contain the one user prompt and the system guidance.
  /// Database rows or saved account details are never automatically uploaded.
  static Future<String> ask(String prompt, {bool testConnection = false}) async {
    final config = await load();
    if (!testConnection && !config.enabled) {
      throw StateError('AI internet belum diaktifkan di Pengaturan API');
    }
    final key = await _vault.read(key: _keySlot(config.provider));
    if (key == null || key.isEmpty) {
      throw StateError('API key belum disimpan');
    }
    final normalized = prompt.trim();
    if (normalized.isEmpty || normalized.length > 1200) {
      throw const FormatException('Pesan harus berisi 1–1200 karakter');
    }
    final client = http.Client();
    try {
      final bool isGemini = config.provider == 'gemini';
      final Uri endpoint;
      final Map<String, String> headers;
      final Map<String, Object?> body;
      if (isGemini) {
        endpoint = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(config.model)}:generateContent');
        headers = {'Content-Type': 'application/json', 'x-goog-api-key': key};
        body = {
          'systemInstruction': {'parts': [{'text': _system}]},
          'contents': [{'role': 'user', 'parts': [{'text': normalized}]}],
          'generationConfig': {'maxOutputTokens': config.shortAnswers ? 350 : 850},
        };
      } else {
        endpoint = Uri.parse(config.provider == 'groq'
          ? 'https://api.groq.com/openai/v1/chat/completions'
          : 'https://openrouter.ai/api/v1/chat/completions');
        headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'};
        if (config.provider == 'openrouter') headers['X-Title'] = 'AGAN PONSEL AGANA';
        body = {
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': _system},
            {'role': 'user', 'content': normalized},
          ],
          'max_tokens': config.shortAnswers ? 350 : 850,
          'stream': false,
        };
      }
      final response = await client.post(endpoint, headers: headers,
        body: jsonEncode(body)).timeout(const Duration(seconds: 28));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError('API key ditolak atau tidak memiliki izin. Periksa penyedia AI.');
      }
      if (response.statusCode == 429) {
        throw StateError('Kuota AI atau batas permintaan tercapai. Coba lagi nanti.');
      }
      if (response.statusCode >= 400) {
        // Do not display or log potentially sensitive provider response bodies.
        throw StateError('Layanan AI tidak dapat memproses permintaan (HTTP ${response.statusCode}). Periksa model dan kuota.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException('Respons AI tidak valid');
      String text;
      if (isGemini) {
        final candidates = decoded['candidates'] as List<dynamic>?;
        final content = candidates?.isNotEmpty == true ? candidates!.first['content'] as Map<String, dynamic>? : null;
        final parts = content?['parts'] as List<dynamic>?;
        text = parts?.whereType<Map<String, dynamic>>()
          .map((part) => '${part['text'] ?? ''}').where((s) => s.trim().isNotEmpty).join('\n') ?? '';
      } else {
        final choices = decoded['choices'] as List<dynamic>?;
        final message = choices?.isNotEmpty == true ? choices!.first['message'] as Map<String, dynamic>? : null;
        text = '${message?['content'] ?? ''}';
      }
      if (text.trim().isEmpty) throw StateError('Model tidak mengembalikan teks. Coba model lain.');
      return text.trim();
    } on TimeoutException {
      throw StateError('Waktu koneksi AI habis. Periksa internet atau coba lagi.');
    } on http.ClientException {
      throw StateError('Tidak dapat menghubungi layanan AI. Periksa jaringan.');
    } finally {
      client.close();
    }
  }
}
