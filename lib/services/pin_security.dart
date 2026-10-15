import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local UI lock. This does NOT encrypt SQLite or backup files.
class PinSecurity {
  PinSecurity._();
  static const _hashKey = 'local_pin_hash_v1';
  static const _saltKey = 'local_pin_salt_v1';
  static const _failsKey = 'local_pin_failures_v1';
  static const _untilKey = 'local_pin_locked_until_v1';
  static const pinLength = 6;

  static Future<bool> get enabled async =>
      (await SharedPreferences.getInstance()).containsKey(_hashKey);

  static bool valid(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  static String _slowHash(String data) {
    List<int> bytes = utf8.encode(data);
    for (var i = 0; i < 65000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64UrlEncode(bytes);
  }

  static Future<String> _digest(String salt, String pin) =>
      compute(_slowHash, '$salt:$pin');

  static Future<void> enable(String pin) async {
    if (!valid(pin)) throw const FormatException('PIN harus 6 digit angka');
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_hashKey)) throw StateError('PIN sudah aktif');
    final random = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(20, (_) => random.nextInt(256)));
    final digest = await _digest(salt, pin);
    await prefs.setString(_saltKey, salt);
    await prefs.setString(_hashKey, digest);
    await prefs.remove(_failsKey);
    await prefs.remove(_untilKey);
  }

  static Future<PinAttempt> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_hashKey);
    final salt = prefs.getString(_saltKey);
    if (hash == null || salt == null) return const PinAttempt(true, 0);
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = prefs.getInt(_untilKey) ?? 0;
    if (until > now) return PinAttempt(false, ((until - now) / 1000).ceil());
    if (!valid(pin)) return const PinAttempt(false, 0);
    final entered = await _digest(salt, pin);
    // Compare whole digests, no PIN is stored as plaintext.
    if (entered == hash) {
      await prefs.remove(_failsKey);
      await prefs.remove(_untilKey);
      return const PinAttempt(true, 0);
    }
    final fails = (prefs.getInt(_failsKey) ?? 0) + 1;
    if (fails >= 5) {
      const seconds = 30;
      await prefs.setInt(_untilKey, now + seconds * 1000);
      await prefs.setInt(_failsKey, 0);
      return const PinAttempt(false, seconds);
    }
    await prefs.setInt(_failsKey, fails);
    return const PinAttempt(false, 0);
  }

  static Future<bool> change(String oldPin, String newPin) async {
    if (!valid(newPin)) throw const FormatException('PIN baru harus 6 digit');
    final ok = await verify(oldPin);
    if (!ok.accepted) return false;
    final prefs = await SharedPreferences.getInstance();
    final random = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(20, (_) => random.nextInt(256)));
    final hash = await _digest(salt, newPin);
    await prefs.setString(_saltKey, salt);
    await prefs.setString(_hashKey, hash);
    return true;
  }

  static Future<bool> disable(String oldPin) async {
    final ok = await verify(oldPin);
    if (!ok.accepted) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_saltKey);
    await prefs.remove(_failsKey);
    await prefs.remove(_untilKey);
    return true;
  }
}

class PinAttempt {
  final bool accepted;
  final int cooldownSeconds;
  const PinAttempt(this.accepted, this.cooldownSeconds);
}
