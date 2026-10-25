import 'package:shared_preferences/shared_preferences.dart';

/// Public shop identity supplied by the owner. Never infer business contact
/// details from a device or publish the private account-owner phone number.
class StoreAboutProfile {
  static const String aboutKey = 'local_shop_about';
  static const String hoursKey = 'local_shop_hours';
  static const String phoneKey = 'local_shop_contact_phone';
  static const String whatsappKey = 'local_shop_contact_whatsapp';
  static const String emailKey = 'local_shop_contact_email';
  static const String instagramKey = 'local_shop_instagram';
  static const String websiteKey = 'local_shop_website';

  final String name;
  final String description;
  final String address;
  final String hours;
  final String phone;
  final String whatsapp;
  final String email;
  final String instagram;
  final String website;

  const StoreAboutProfile({
    required this.name,
    required this.description,
    required this.address,
    required this.hours,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.instagram,
    required this.website,
  });

  static Future<StoreAboutProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StoreAboutProfile(
      name: prefs.getString('local_shop_name')?.trim().isNotEmpty == true
          ? prefs.getString('local_shop_name')!.trim()
          : 'AGAN PONSEL',
      description: prefs.getString(aboutKey) ?? '',
      address: prefs.getString('local_shop_address') ??
          'Sekeladi, Tanah Putih, Riau',
      hours: prefs.getString(hoursKey) ?? '',
      phone: prefs.getString(phoneKey) ?? '',
      whatsapp: prefs.getString(whatsappKey) ?? '',
      email: prefs.getString(emailKey) ?? '',
      instagram: prefs.getString(instagramKey) ?? '',
      website: prefs.getString(websiteKey) ?? '',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final fields = <String, String>{
      'local_shop_name': name.trim(),
      'local_shop_address': address.trim(),
      aboutKey: description.trim(),
      hoursKey: hours.trim(),
      phoneKey: phone.trim(),
      whatsappKey: whatsapp.trim(),
      emailKey: email.trim(),
      instagramKey: instagram.trim().replaceFirst(RegExp(r'^@'), ''),
      websiteKey: website.trim(),
    };
    for (final entry in fields.entries) {
      if (!await prefs.setString(entry.key, entry.value)) {
        throw StateError('Gagal menyimpan ${entry.key}');
      }
    }
  }

  String toShareText() {
    final lines = <String>[
      name,
      if (description.trim().isNotEmpty) description.trim(),
      if (hours.trim().isNotEmpty) 'Jam operasional: ${hours.trim()}',
      if (address.trim().isNotEmpty) 'Alamat: ${address.trim()}',
      if (phone.trim().isNotEmpty) 'Telepon: ${phone.trim()}',
      if (whatsapp.trim().isNotEmpty) 'WhatsApp: ${whatsapp.trim()}',
      if (email.trim().isNotEmpty) 'Email: ${email.trim()}',
      if (instagram.trim().isNotEmpty) 'Instagram: @${instagram.trim().replaceFirst(RegExp(r'^@'), '')}',
      if (website.trim().isNotEmpty) 'Situs web: ${website.trim()}',
    ];
    return lines.join('\n');
  }
}

class ShopContactLinks {
  ShopContactLinks._();

  static String? whatsappNumber(String value) {
    final input = value.trim();
    if (input.isEmpty || !RegExp(r'^\+?[0-9()\s-]+$').hasMatch(input)) {
      return null;
    }
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0062')) digits = digits.substring(2);
    if (digits.startsWith('08')) digits = '62${digits.substring(1)}';
    if (!digits.startsWith('628') || digits.length < 10 || digits.length > 15) {
      return null;
    }
    return digits;
  }

  static Uri? whatsappUri(String value) {
    final number = whatsappNumber(value);
    return number == null ? null : Uri.https('wa.me', '/$number');
  }

  static Uri? phoneUri(String value) {
    final input = value.trim();
    if (!RegExp(r'^\+?[0-9()\s-]{8,24}$').hasMatch(input)) return null;
    final sanitized = input.replaceAll(RegExp(r'[^0-9+]'), '');
    return Uri(scheme: 'tel', path: sanitized);
  }

  static bool validEmail(String value) {
    final input = value.trim();
    return input.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input);
  }

  static Uri? emailUri(String value) {
    if (value.trim().isEmpty || !validEmail(value)) return null;
    return Uri(scheme: 'mailto', path: value.trim());
  }

  static Uri? instagramUri(String value) {
    final handle = value.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[a-zA-Z0-9._]{1,30}$').hasMatch(handle)) return null;
    return Uri.https('www.instagram.com', '/$handle/');
  }

  static Uri? websiteUri(String value) {
    final input = value.trim();
    if (input.isEmpty) return null;
    final candidate = input.contains('://') ? input : 'https://$input';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        uri.host.isEmpty || !uri.host.contains('.') || uri.host.contains(' ')) {
      return null;
    }
    return uri;
  }
}
