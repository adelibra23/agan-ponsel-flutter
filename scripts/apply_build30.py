#!/usr/bin/env python3
"""Build29 -> Build30: private reminders, sculpted UI and Android Face unlock.

Applies only to Flutter source in the current repository. It never opens,
modifies or deletes SQLite files, PIN hashes, keys, or Android signing files.
Validates all replacement anchors before writing anything; safe to rerun.
"""
from pathlib import Path
import re
import sys

VERSION_OLD = 'version: 1.9.0+29'
VERSION_NEW = 'version: 2.0.0+30'
ARTIFACT_OLD = 'AGAN-PONSEL-v1.9.0-Build29-APK'
ARTIFACT_NEW = 'AGAN-PONSEL-v2.0.0-Build30-APK'


def single(src, before, after, label):
    if src.count(before) != 1:
        raise ValueError(f'{label}: perlu tepat satu anchor, ditemukan {src.count(before)}')
    return src.replace(before, after, 1)


def span(src, start, end, replacement, label):
    if src.count(start) != 1 or src.count(end) != 1:
        raise ValueError(f'{label}: anchor class berubah, pembaruan dibatalkan')
    a, b = src.index(start), src.index(end)
    if a >= b:
        raise ValueError(f'{label}: urutan class tidak sesuai')
    return src[:a] + replacement + '\n\n' + src[b:]


def dashboard(src):
    marker = '// BUILD30_REMINDERS_PRIVATE'
    if marker in src:
        return src
    reminder = '''        _DebtReminderCard(onOpen: () => widget.open(const ReminderCenterScreen()),
          onAll: () => widget.open(const ReceivablesScreen())),
        const SizedBox(height: 12),
'''
    src = single(src, reminder,
        '''        // BUILD30_REMINDERS_PRIVATE: no due dates or outstanding debt amounts
        // on the dashboard. Reminders remain available through the bell/menu.
''', 'reminder dashboard')
    # The debt reminder class is the final declaration in Build29's dashboard.
    decl = 'class _DebtReminderCard extends StatelessWidget {'
    if src.count(decl) != 1:
        raise ValueError('reminder helper not found')
    src = src[:src.index(decl)].rstrip() + '\n'
    src = single(src, "import '../services/receivables_service.dart';\n", '', 'unused reminder import')
    src = single(src,
        "const SectionTitle('Ringkasan hari ini', subtitle: 'Pantau performa toko secara langsung'),",
        "const SectionTitle('Ringkasan Hari Ini', subtitle: 'Statistik real-time • visual dengan efek kedalaman'),",
        'dashboard summary label')
    # Updated action iconography, with the same business routes.
    for before, after in [
        ('Icons.build_circle_outlined', 'Icons.handyman_rounded'),
        ('Icons.smartphone_rounded', 'Icons.sim_card_rounded'),
        ('Icons.bar_chart_rounded', 'Icons.analytics_rounded'),
        ('Icons.account_balance_wallet_outlined', 'Icons.account_balance_wallet_rounded'),
        ('Icons.task_alt_rounded', 'Icons.task_alt_rounded'),
    ]:
        if before in src:
            src = src.replace(before, after)
    return src


STAT_TILE = '''/// BUILD30_DEPTH_TILES: layered translucent surfaces and soft elevation.
/// No tilt sensor, expensive continuous animation or altered financial data.
class StatTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const StatTile({super.key, required this.title, required this.value,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Color.alphaBlend(
      color.withValues(alpha: dark ? .20 : .10), scheme.surface);
    final glow = Color.alphaBlend(
      color.withValues(alpha: dark ? .11 : .06), scheme.surface);
    return Semantics(label: '$title: $value', child: AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, base, glow]),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: dark ? .10 : .14),
            blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withValues(alpha: dark ? .16 : .045),
            blurRadius: 8, spreadRadius: -3, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          Positioned(right: -20, top: -27, child: Container(width: 103,
            height: 103, decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .11), width: 17)))),
          Positioned(left: 12, right: 12, top: 1,
            child: Container(height: 1, color: Colors.white.withValues(
              alpha: dark ? .12 : .75))),
          Padding(padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant,
                      fontSize: 11.5, fontWeight: FontWeight.w800,
                      height: 1.15))),
                  const SizedBox(width: 5),
                  Container(width: 35, height: 35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withValues(alpha: .92),
                          color.withValues(alpha: .72)]),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: .22),
                        blurRadius: 8, offset: const Offset(0, 4))]),
                    child: Icon(icon, color: Colors.white, size: 18)),
                ]),
                SizedBox(width: double.infinity,
                  child: FittedBox(fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, maxLines: 1,
                      style: TextStyle(fontSize: 21, letterSpacing: -.6,
                        color: scheme.onSurface, fontWeight: FontWeight.w900)))),
              ])),
        ])),
    ));
  }
}'''

QUICK_ICON = '''/// Clean Material 3 shortcuts with softer glass depth and feedback.
class QuickIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback action;
  const QuickIcon({super.key, required this.icon, required this.color,
    required this.label, required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: action, borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          Container(width: 55, height: 55,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft,
                end: Alignment.bottomRight, colors: [
                  color.withValues(alpha: .17),
                  color.withValues(alpha: .055)]),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: color.withValues(alpha: .15)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .08),
                blurRadius: 11, offset: const Offset(0, 5))]),
            child: Icon(icon, color: color, size: 25)),
          const SizedBox(height: 8),
          Text(label, maxLines: 2, textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
    );
  }
}'''


def kit(src):
    if 'BUILD30_DEPTH_TILES' in src:
        return src
    src = span(src, 'class QuickIcon extends StatelessWidget {',
        '/// Dashboard metric card.', QUICK_ICON, 'quick icons')
    src = span(src, 'class StatTile extends StatelessWidget {',
        'class ScreenLoading extends StatelessWidget', STAT_TILE, '3D summary')
    return src


BOTTOM_BAR = '''// BUILD30_MOTION_BOTTOM: sliding selection capsule, spring icons, semantic labels.
// All actual page states remain mounted in the existing IndexedStack.
class AnimatedBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelected;
  const AnimatedBottomBar({super.key, required this.index,
    required this.onSelected});

  static const labels = ['Beranda', 'Kasir', 'Produk', 'Service', 'Lainnya'];
  static const icons = [Icons.home_outlined, Icons.point_of_sale_outlined,
    Icons.inventory_2_outlined, Icons.handyman_outlined,
    Icons.apps_outlined];
  static const selectedIcons = [Icons.home_rounded, Icons.point_of_sale_rounded,
    Icons.inventory_2_rounded, Icons.handyman_rounded, Icons.apps_rounded];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .5))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(
          alpha: dark ? .20 : .06), blurRadius: 19,
          offset: const Offset(0, -4))]),
      child: SafeArea(top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return SizedBox(height: 63, child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 390),
              curve: Curves.easeOutCubic,
              left: index * tabWidth + (tabWidth - 54) / 2,
              top: 3, width: 54, height: 35,
              child: DecoratedBox(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight, colors: [scheme.primary,
                    Color.lerp(scheme.primary, scheme.secondary, .35)!]),
                boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .24),
                  blurRadius: 13, offset: const Offset(0, 5))]))),
            Row(children: List.generate(labels.length, (i) {
              final active = i == index;
              return Expanded(child: Semantics(
                button: true, selected: active, label: labels[i],
                child: InkWell(
                  onTap: () {
                    if (i != index) {
                      HapticFeedback.selectionClick();
                      onSelected(i);
                    }
                  },
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(height: 63,
                    child: Column(mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: 39, child: Center(
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 310),
                            curve: Curves.easeOutBack,
                            scale: active ? 1.12 : .94,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation,
                                  child: FadeTransition(opacity: animation,
                                    child: child)),
                              child: Icon(active ? selectedIcons[i] : icons[i],
                                key: ValueKey('$i-$active'), size: 22,
                                color: active ? Colors.white
                                  : scheme.onSurfaceVariant))),
                        )),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(fontSize: 10,
                            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                            color: active ? scheme.primary
                              : scheme.onSurfaceVariant),
                          child: Text(labels[i], maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                      ])),
                  ),
                ),
              );
            })),
          ]));
        })),
    );
  }
}'''


def identity(src):
    if 'BUILD30_MOTION_BOTTOM' in src:
        return src
    marker = 'class AnimatedBottomBar extends StatelessWidget {'
    if src.count(marker) != 1:
        raise ValueError('AnimatedBottomBar declaration not found')
    # The original bar is the last declaration in identity.dart.
    return src[:src.index(marker)] + BOTTOM_BAR + '\n'


def biometrics(src):
    if 'BUILD30_ANDROID_FACE_PREFERENCE' in src:
        return src
    block = '''  // BUILD30_ANDROID_FACE_PREFERENCE: Android platform controls which sensor
  // actually satisfies its prompt. No facial images/templates enter this app.
  static const faceKey = 'local_face_preferred_v30';

  static Future<bool> get faceAvailable async {
    try {
      if (!await _device.isDeviceSupported()) return false;
      final types = await _device.getAvailableBiometrics();
      return types.contains(BiometricType.face);
    } catch (_) { return false; }
  }

  static Future<bool> get facePreferred async =>
      (await SharedPreferences.getInstance()).getBool(faceKey) ?? false;

  static Future<bool> enableFacePreference() async {
    if (!await PinSecurity.enabled || !await faceAvailable) return false;
    // Verify using the trusted Android biometric dialog before saving.
    if (!await authenticate()) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
    return prefs.setBool(faceKey, true);
  }

  static Future<void> disableFacePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(faceKey, false);
  }

'''
    return single(src, '  static Future<bool> authenticate() async {',
        block + '  static Future<bool> authenticate() async {', 'face Android methods')


def pins(src):
    marker = '// BUILD30_PIN_FACE_UI'
    if marker in src:
        return src
    src = single(src,
        '''  bool biometricsReady = false;
  String message''',
        '''  bool biometricsReady = false;
  bool faceReady = false;
  bool facePromptAttempted = false;
  String message''', 'unlock flags')
    src = single(src,
        '''      final available = enabled && await BiometricSecurity.available;
      if (mounted) setState(() => biometricsReady = available);''',
        '''      final available = enabled && await BiometricSecurity.available;
      final face = available && await BiometricSecurity.facePreferred &&
        await BiometricSecurity.faceAvailable;
      if (!mounted) return;
      setState(() { biometricsReady = available; faceReady = face; });
      if (face && !facePromptAttempted) {
        facePromptAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !busy) unlockBiometric();
        });
      }''', 'prompt after PIN unlock init')
    src = single(src,
        '''            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Buka dengan Biometrik')),''',
        '''            icon: Icon(faceReady ? Icons.face_retouching_natural_rounded
              : Icons.fingerprint_rounded),
            label: Text(faceReady ? 'Verifikasi Wajah / Biometrik'
              : 'Buka dengan Biometrik')),''', 'unlock face button')
    src = single(src,
        '''  bool biometricsAvailable = false;

  @override''',
        '''  bool biometricsAvailable = false;
  // BUILD30_PIN_FACE_UI: face is optional, PIN is always the fallback.
  bool faceAvailable = false;
  bool facePreferred = false;

  @override''', 'face settings flags')
    src = single(src,
        '''    final available = await BiometricSecurity.available;
    if (mounted) setState(() {
      enabled = value; biometricsEnabled = biometric; biometricsAvailable = available;
    });''',
        '''    final available = await BiometricSecurity.available;
    final face = await BiometricSecurity.faceAvailable;
    final preferred = await BiometricSecurity.facePreferred;
    if (mounted) setState(() {
      enabled = value;
      biometricsEnabled = biometric;
      biometricsAvailable = available;
      faceAvailable = face;
      facePreferred = preferred;
    });''', 'face refresh')
    src = single(src,
        '''      if (success) {
        oldPin.clear();''',
        '''      if (success) {
        if (disable) {
          await BiometricSecurity.disableFacePreference();
          await BiometricSecurity.disable();
        }
        oldPin.clear();''', 'PIN disable clears face preference')
    # Turning off biometrics also turns off the stored preference.
    src = single(src,
        '''      } else {
        await BiometricSecurity.disable();
        if (mounted) notify(context, 'Biometrik dinonaktifkan');
      }''',
        '''      } else {
        await BiometricSecurity.disableFacePreference();
        await BiometricSecurity.disable();
        if (mounted) notify(context, 'Biometrik dinonaktifkan');
      }''', 'biometric disable')
    method = '''  Future<void> toggleFace(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (value) {
        final approved = await BiometricSecurity.enableFacePreference();
        if (mounted) notify(context, approved
          ? 'Prioritas wajah Android diaktifkan.'
          : 'Wajah belum tersedia atau verifikasi dibatalkan. Gunakan PIN.');
      } else {
        await BiometricSecurity.disableFacePreference();
        if (mounted) notify(context, 'Prioritas wajah dinonaktifkan');
      }
      await refresh();
    } catch (e) {
      if (mounted) notify(context, 'Tidak bisa mengubah pengaturan wajah: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

'''
    src = single(src, '  Widget pinField(TextEditingController c, String title) =>',
        method + '  Widget pinField(TextEditingController c, String title) =>',
        'face toggle method')
    anchor = '''      const SizedBox(height: 15),
      const Surface(child: Text('Keamanan: PIN disimpan sebagai hash'''
    faceUi = '''      const SizedBox(height: 12),
      Surface(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.face_retouching_natural_rounded,
          color: brandBlue),
        title: const Text('Prioritaskan Scan Wajah Android',
          style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(faceAvailable
          ? 'Tampilkan prompt biometrik saat membuka kunci. '
            'Android dapat menawarkan sensor lain; PIN selalu tersedia.'
          : 'Face Unlock belum terdeteksi oleh API biometrik Android pada HP ini.'),
        value: facePreferred && enabled && faceAvailable,
        onChanged: !enabled || !faceAvailable || busy ? null : toggleFace,
      )),
      const SizedBox(height: 10),
      const Surface(child: Text('Biometrik wajah mengikuti kemampuan sensor dan '
        'kebijakan Android. Aplikasi tidak menyimpan foto wajah atau template '
        'biometrik. Pastikan PIN aktif sebagai metode pemulihan.')),
'''
    return single(src, anchor, faceUi + anchor, 'face switch placement')


def pubspec(src):
    return single(src, VERSION_OLD, VERSION_NEW, 'app version')


def workflow(src):
    src = single(src, ARTIFACT_OLD, ARTIFACT_NEW, 'artifact version')
    anchor = '      - name: Analyze Flutter code'
    check = '''      - name: Verify Build30 dashboard privacy, motion and Face Unlock
        run: |
          python3 scripts/check_build30.py
          python3 scripts/smoke_build30_privacy.py

'''
    src = single(src, anchor, check + anchor, 'new regression check')
    return single(src, 'test/build29_cash_card_test.dart',
        'test/build29_cash_card_test.dart test/build30_ui_security_test.dart',
        'widget test append')


def check29(src):
    return single(src, VERSION_OLD, VERSION_NEW, 'Build29 previous version test').replace(
        ARTIFACT_OLD, ARTIFACT_NEW)


def main():
    root = Path.cwd()
    pub = root / 'pubspec.yaml'
    if not pub.exists():
        raise SystemExit('Bukan direktori source Flutter AGAN PONSEL.')
    current = pub.read_text()
    if VERSION_NEW in current:
        required = ['BUILD30_REMINDERS_PRIVATE', 'BUILD30_DEPTH_TILES',
          'BUILD30_MOTION_BOTTOM', 'BUILD30_ANDROID_FACE_PREFERENCE',
          'BUILD30_PIN_FACE_UI']
        paths = ['lib/screens/dashboard.dart', 'lib/widgets/kit.dart',
          'lib/widgets/identity.dart', 'lib/services/biometric_security.dart',
          'lib/screens/security/pin_screens.dart']
        missing = [p for p, token in zip(paths, required)
          if token not in (root / p).read_text()]
        if missing:
            raise SystemExit('Versi Build30 ada, tapi source belum lengkap: '+str(missing))
        print('OK: Build30 sudah diterapkan, tidak ada file yang diubah')
        return
    if VERSION_OLD not in current:
        raise SystemExit('Build30 harus dipasang di atas AGAN PONSEL v1.9.0+29.')
    patches = {
      'lib/screens/dashboard.dart': dashboard,
      'lib/widgets/kit.dart': kit,
      'lib/widgets/identity.dart': identity,
      'lib/services/biometric_security.dart': biometrics,
      'lib/screens/security/pin_screens.dart': pins,
      'pubspec.yaml': pubspec,
      '.github/workflows/build-apk.yml': workflow,
      'scripts/check_build29.py': check29,
    }
    prepared = {}
    for name, func in patches.items():
        target = root / name
        if not target.is_file():
            raise SystemExit('File tidak tersedia: '+name)
        try:
            prepared[target] = func(target.read_text())
        except Exception as exc:
            raise SystemExit('PATCH DIBATALKAN di '+name+': '+str(exc)) from exc
    for file, updated in prepared.items():
        file.write_text(updated)
        print('UPDATED', file.relative_to(root))
    print('OK: Build30 terpasang; data SQLite dan PIN tidak disentuh')

if __name__ == '__main__':
    main()
