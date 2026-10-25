#!/usr/bin/env python3
"""Runs patch twice against known Build29 anchor fixtures; no Flutter SDK.

Verifies repeat safety, atomic pre-validation and wrong-version refusal.
"""
from pathlib import Path
import subprocess
import tempfile
import sys
import hashlib

PATCH = Path(__file__).resolve().parent / 'apply_build30.py'

FIXTURE = {
'pubspec.yaml': '''name: agan_ponsel
version: 1.9.0+29
''',
'lib/screens/dashboard.dart': '''import '../services/receivables_service.dart';
import 'receivables.dart';
class Test {
  Widget build(BuildContext context) => Column(children: [
        _DebtReminderCard(onOpen: () => widget.open(const ReminderCenterScreen()),
          onAll: () => widget.open(const ReceivablesScreen())),
        const SizedBox(height: 12),
        const SectionTitle('Ringkasan hari ini', subtitle: 'Pantau performa toko secara langsung'),
        Icons.build_circle_outlined,
        Icons.smartphone_rounded,
        Icons.bar_chart_rounded,
  ]);
}
class _DebtReminderCard extends StatelessWidget {
  const _DebtReminderCard();
}
''',
'lib/widgets/kit.dart': '''class QuickIcon extends StatelessWidget {
  Widget build(BuildContext context) => const SizedBox();
}
/// Dashboard metric card. Values always use the theme's onSurface color
class StatTile extends StatelessWidget {
  Widget build(BuildContext context) => const SizedBox();
}
class ScreenLoading extends StatelessWidget {
  Widget build(BuildContext context) => const SizedBox();
}
''',
'lib/widgets/identity.dart': '''import 'package:flutter/material.dart';
class AnimatedBottomBar extends StatelessWidget {
  Widget build(BuildContext context) => const SizedBox();
}
''',
'lib/services/biometric_security.dart': '''import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_security.dart';
class BiometricSecurity {
  static const key = 'local_biometrics_enabled_v1';
  static final LocalAuthentication _device = LocalAuthentication();
  static Future<bool> authenticate() async { return false; }
}
''',
'lib/screens/security/pin_screens.dart': '''class _PinUnlockScreenState {
  bool biometricsReady = false;
  String message = '';
  Future<void> checkBiometrics() async {
    final enabled = await BiometricSecurity.isEnabled;
      final available = enabled && await BiometricSecurity.available;
      if (mounted) setState(() => biometricsReady = available);
  }
  Widget button() => OutlinedButton.icon(onPressed: busy ? null : unlockBiometric,
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Buka dengan Biometrik')),
}
class _PinSettingsScreenState {
  bool biometricsAvailable = false;

  @override
  void initState(){}
  Future<void> refresh() async {
    final value = await PinSecurity.enabled;
    final biometric = await BiometricSecurity.isEnabled;
    final available = await BiometricSecurity.available;
    if (mounted) setState(() {
      enabled = value; biometricsEnabled = biometric; biometricsAvailable = available;
    });
  }
  Future<void> submit({required bool disable}) async {
      if (success) {
        oldPin.clear(); newPin.clear(); confirmPin.clear();
      }
  }
  Future<void> toggleBiometrics(bool value) async {
      } else {
        await BiometricSecurity.disable();
        if (mounted) notify(context, 'Biometrik dinonaktifkan');
      }
  }
  Widget pinField(TextEditingController c, String title) => const SizedBox();
  Widget build(BuildContext context) => ListView(children: [
      const SizedBox(height: 15),
      const Surface(child: Text('Keamanan: PIN disimpan sebagai hash dan salt')),
  ]);
}
''',
'.github/workflows/build-apk.yml': '''      - name: Analyze Flutter code
        run: flutter analyze
      - name: Run basic unit tests
        run: flutter test test/build29_cash_card_test.dart
      - name: Upload APK
        with:
          name: AGAN-PONSEL-v1.9.0-Build29-APK
''',
'scripts/check_build29.py': '''checks = {'pubspec.yaml': ['version: 1.9.0+29'],
'.github/workflows/build-apk.yml': ['AGAN-PONSEL-v1.9.0-Build29-APK']}
''',
}


def run(root):
    return subprocess.run([sys.executable, str(PATCH)], cwd=root,
        text=True, capture_output=True)


def populate(root):
    for name, code in FIXTURE.items():
        path = root/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(code)


def checksum(root):
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in root.rglob('*') if p.is_file()}

with tempfile.TemporaryDirectory(prefix='agan-build30-') as tmp:
    root = Path(tmp)
    populate(root)
    first = run(root)
    assert first.returncode == 0, f'first upgrade failed:\n{first.stderr}{first.stdout}'
    assert 'version: 2.0.0+30' in (root/'pubspec.yaml').read_text()
    result = checksum(root)
    again = run(root)
    assert again.returncode == 0, f'idempotence failed: {again.stderr}{again.stdout}'
    assert result == checksum(root), 'Second run altered previously patched files'

with tempfile.TemporaryDirectory(prefix='agan-build30-invalid-') as tmp:
    root = Path(tmp)
    populate(root)
    (root/'lib/widgets/kit.dart').write_text('file was changed by another user')
    old = checksum(root)
    failed = run(root)
    assert failed.returncode != 0, 'Expected failing on missing critical widget anchor'
    assert checksum(root) == old, 'Patch changed other files before anchor validation'

with tempfile.TemporaryDirectory(prefix='agan-build30-wrong-') as tmp:
    root = Path(tmp)
    populate(root)
    (root/'pubspec.yaml').write_text('version: 1.8.0+28\n')
    old = checksum(root)
    failed = run(root)
    assert failed.returncode != 0 and checksum(root) == old

print('OK: Build30 patch first run, repeated run, fail-fast anchor guard, wrong-version guard')
