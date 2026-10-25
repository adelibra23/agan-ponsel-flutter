#!/usr/bin/env python3
"""Apply Build31 on top of AGAN PONSEL Build30.

No database migration or local user-data deletion. Verifies every source anchor
before writing, and is safe to run twice. Keep package signing unchanged.
"""
from pathlib import Path
import re
import sys

ROOT = Path.cwd()


def replace_once(source: str, before: str, after: str, label: str) -> str:
    if after in source:
        return source
    count = source.count(before)
    if count != 1:
        raise RuntimeError(f'{label}: perlu tepat 1 anchor, ditemukan {count}')
    return source.replace(before, after, 1)


def update_main(s: str) -> str:
    s = replace_once(s,
        'class _AppShellState extends State<AppShell> {',
        'class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {',
        'tab motion lifecycle')
    insertion = '''  // BUILD31_TAB_CONTENT_MOTION: animate content without rebuilding tab state.
  late final AnimationController _tabMotion = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  bool _tabMovesForward = true;

  @override
  void dispose() {
    _tabMotion.dispose();
    super.dispose();
  }

'''
    s = replace_once(s, '  int selected = 0;', insertion + '  int selected = 0;',
        'tab animation controller')
    s = replace_once(s,
        '''  void select(int tab) {
    if (tab != selected) setState(() => selected = tab);
  }''',
        '''  void select(int tab) {
    if (tab < 0 || tab >= titles.length || tab == selected) return;
    _tabMovesForward = tab > selected;
    setState(() => selected = tab);
    _tabMotion.forward(from: 0);
  }''',
        'tab select')
    s = replace_once(s,
        'Expanded(child: IndexedStack(index: selected, children: pages)),',
        '''Expanded(child: AnimatedBuilder(
            animation: _tabMotion,
            child: IndexedStack(index: selected, children: pages),
            builder: (context, child) {
              final progress = Curves.easeOutCubic.transform(_tabMotion.value);
              final direction = _tabMovesForward ? 1.0 : -1.0;
              return Opacity(
                opacity: .83 + .17 * progress,
                child: Transform.translate(
                  offset: Offset(18 * direction * (1 - progress), 0),
                  child: Transform.scale(
                    scale: .985 + .015 * progress,
                    child: child,
                  ),
                ),
              );
            },
          )),''',
        'animated IndexedStack')
    return s


def update_settings(s: str) -> str:
    if "import 'about_store.dart';" not in s:
        anchor = "import '../../widgets/store_logo.dart';"
        s = replace_once(s, anchor, anchor + "\nimport 'about_store.dart';", 'about store import')
    begin = 'class AboutAganScreen extends StatelessWidget {'
    end = 'class StoreBrandSettingsScreen extends StatefulWidget {'
    wrapper = '''// BUILD31_ABOUT_WRAPPER — preserve previous route API for Menu and Settings.
class AboutAganScreen extends StatelessWidget {
  const AboutAganScreen({super.key});
  @override
  Widget build(BuildContext context) => const AboutStoreScreen();
}

'''
    if 'BUILD31_ABOUT_WRAPPER' in s:
        return s
    if s.count(begin) != 1 or s.count(end) != 1:
        raise RuntimeError('About screen boundaries differ from Build30')
    a = s.index(begin)
    b = s.index(end)
    if b <= a:
        raise RuntimeError('Invalid About screen boundaries')
    return s[:a] + wrapper + s[b:]


def update_backup(s: str) -> str:
    anchor = "    'local_shop_name', 'local_shop_address', 'local_receipt_footer',"
    addon = '''    // Public store contact, about text and opening hours; no PIN/face data.
    'local_shop_about', 'local_shop_hours',
    'local_shop_contact_phone', 'local_shop_contact_whatsapp',
    'local_shop_contact_email', 'local_shop_instagram',
    'local_shop_website','''
    return replace_once(s, anchor, anchor + '\n' + addon, 'about contact backup')


def update_pubspec(s: str) -> str:
    s = replace_once(s, 'version: 2.0.0+30', 'version: 2.1.0+31', 'pubspec version')
    if 'package_info_plus:' not in s:
        anchor = '  shared_preferences: ^2.5.3'
        s = replace_once(s, anchor, anchor + '\n  package_info_plus: ^8.3.1',
            'version info dependency')
    return s


def update_workflow(s: str) -> str:
    s = replace_once(s,
        'AGAN-PONSEL-v2.0.0-Build30-APK',
        'AGAN-PONSEL-v2.1.0-Build31-APK',
        'APK artifact name')
    if 'scripts/check_build31.py' not in s:
        anchor = '      - name: Analyze Flutter code'
        step = '''      - name: Check Build31 animated tabs and editable About
        run: |
          python3 scripts/check_build31.py
          python3 scripts/smoke_build31_about_backup.py

'''
        s = replace_once(s, anchor, step + anchor, 'Build31 CI smoke checks')
    s = replace_once(s,
        'test/build30_ui_security_test.dart',
        'test/build30_ui_security_test.dart test/build31_about_test.dart',
        'Build31 unit tests')
    return s


def update_old_guard(s: str) -> str:
    s = replace_once(s, 'version: 2.0.0+30', 'version: 2.1.0+31',
        'legacy guard version')
    s = replace_once(s, 'AGAN-PONSEL-v2.0.0-Build30-APK',
        'AGAN-PONSEL-v2.1.0-Build31-APK', 'legacy guard artifact')
    return s


def update_check30(s: str) -> str:
    # The Build30 regression guard checks both pubspec/workflow and the Build29
    # regression guard; the version and artifact appear twice deliberately.
    for original, replacement in [
        ('version: 2.0.0+30', 'version: 2.1.0+31'),
        ('AGAN-PONSEL-v2.0.0-Build30-APK',
         'AGAN-PONSEL-v2.1.0-Build31-APK'),
    ]:
        if replacement in s and original not in s:
            continue
        count = s.count(original)
        if count != 2:
            raise RuntimeError(f'Build30 guard expected 2 {original!r}, got {count}')
        s = s.replace(original, replacement)
    return s


def main() -> None:
    required = {
        'lib/main.dart': update_main,
        'lib/screens/settings/settings_pages.dart': update_settings,
        'lib/services/backup_service.dart': update_backup,
        'pubspec.yaml': update_pubspec,
        '.github/workflows/build-apk.yml': update_workflow,
        'scripts/check_build29.py': update_old_guard,
        'scripts/check_build30.py': update_check30,
    }
    version_file = ROOT / 'pubspec.yaml'
    if not version_file.is_file():
        raise RuntimeError('Jalankan dari direktori root proyek AGAN PONSEL')
    version = version_file.read_text()
    if 'version: 2.0.0+30' not in version and 'version: 2.1.0+31' not in version:
        raise RuntimeError('Patch ini memerlukan Build30 (2.0.0+30), bukan source lain')
    for file in ['lib/screens/settings/about_store.dart',
                 'lib/services/store_about_profile.dart',
                 'scripts/check_build31.py', 'test/build31_about_test.dart']:
        if not (ROOT / file).is_file():
            raise RuntimeError(f'File Build31 belum diekstrak: {file}')
    # Fail before touching any file if an anchor in another file is incompatible.
    planned: dict[Path, str] = {}
    for name, fn in required.items():
        dest = ROOT / name
        if not dest.is_file():
            raise RuntimeError(f'File Build30 hilang: {name}')
        original = dest.read_text()
        planned[dest] = fn(original)
    for dest, new_content in planned.items():
        old = dest.read_text()
        if old != new_content:
            dest.write_text(new_content)
            print('UPDATED:', dest.relative_to(ROOT))
        else:
            print('UNCHANGED:', dest.relative_to(ROOT))
    print('OK: AGAN PONSEL Build31 (animated tab content, editable About & contacts)')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('ERROR:', exc, file=sys.stderr)
        raise SystemExit(1)
