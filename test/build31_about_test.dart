import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agan_ponsel/services/store_about_profile.dart';

void main() {
  test('WhatsApp normalizes valid Indonesian mobile phone numbers', () {
    expect(ShopContactLinks.whatsappNumber('0812 3456 7890'), '6281234567890');
    expect(ShopContactLinks.whatsappNumber('+62 812-3456-7890'), '6281234567890');
    expect(ShopContactLinks.whatsappNumber('006281234567890'), '6281234567890');
    expect(ShopContactLinks.whatsappUri('081234567890')?.host, 'wa.me');
    expect(ShopContactLinks.whatsappNumber('test'), isNull);
    expect(ShopContactLinks.whatsappNumber('1234'), isNull);
  });

  test('Website validation permits HTTPS only, never script or credentials', () {
    expect(ShopContactLinks.websiteUri('aganponsel.example')?.scheme, 'https');
    expect(ShopContactLinks.websiteUri('https://aganponsel.example')?.host,
        'aganponsel.example');
    expect(ShopContactLinks.websiteUri('javascript:alert(1)'), isNull);
    expect(ShopContactLinks.websiteUri('http://aganponsel.example'), isNull);
    expect(ShopContactLinks.websiteUri('https://name:pass@host.example'), isNull);
  });

  test('Profile stores explicit business contacts without inventing phone', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final original = await StoreAboutProfile.load();
    expect(original.name, 'AGAN PONSEL');
    expect(original.phone, isEmpty);
    expect(original.whatsapp, isEmpty);

    const updated = StoreAboutProfile(
      name: 'AGAN PONSEL',
      description: 'Service dan aksesoris ponsel',
      address: 'Sekeladi, Tanah Putih, Riau',
      hours: 'Senin - Sabtu',
      phone: '081234567890',
      whatsapp: '081234567890',
      email: 'toko@example.com',
      instagram: 'aganponsel',
      website: 'https://aganponsel.example',
    );
    await updated.save();
    final restored = await StoreAboutProfile.load();
    expect(restored.hours, 'Senin - Sabtu');
    expect(restored.phone, '081234567890');
    expect(restored.toShareText(), contains('WhatsApp: 081234567890'));
    expect(restored.toShareText(), isNot(contains('local_owner_phone')));
  });

  test('Invalid contacts are never opened', () {
    expect(ShopContactLinks.emailUri('invalid'), isNull);
    expect(ShopContactLinks.phoneUri('123'), isNull);
    expect(ShopContactLinks.instagramUri('invalid/name'), isNull);
    expect(ShopContactLinks.instagramUri('@aganponsel')?.host,
        'www.instagram.com');
  });
}
