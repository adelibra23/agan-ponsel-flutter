import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_security.dart';

/// Optional device biometrics (face/fingerprint), always with PIN fallback.
/// Biometric templates remain inside Android's secure subsystem.
class BiometricSecurity {
  BiometricSecurity._();
  static const key = 'local_biometrics_enabled_v1';
  static final LocalAuthentication _device = LocalAuthentication();

  static Future<bool> get isEnabled async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;

  static Future<bool> get available async {
    try {
      if (!await _device.isDeviceSupported()) return false;
      if (!await _device.canCheckBiometrics) return false;
      return (await _device.getAvailableBiometrics()).isNotEmpty;
    } catch (_) { return false; }
  }

  static Future<bool> authenticate() async {
    if (!await available) return false;
    try {
      return await _device.authenticate(
        localizedReason: 'Verifikasi biometrik untuk membuka AGAN PONSEL',
        options: const AuthenticationOptions(
          biometricOnly: true, stickyAuth: true, useErrorDialogs: true));
    } catch (_) { return false; }
  }

  static Future<bool> enable() async {
    if (!await PinSecurity.enabled) return false;
    if (!await authenticate()) return false;
    return (await SharedPreferences.getInstance()).setBool(key, true);
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, false);
  }
}
