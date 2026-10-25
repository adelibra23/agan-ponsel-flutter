#!/usr/bin/env python3
"""Apply Build29 Premium Cash Card on top of Build28; no SQLite mutation.

Run from repository root AFTER extracting the Build29 patch archive.
This script is idempotent and prepares all modified sources before writing.
"""
from pathlib import Path
import re

NEW_VERSION = 'version: 1.9.0+29'
OLD_VERSION = 'version: 1.8.0+28'
NEW_ARTIFACT = 'AGAN-PONSEL-v1.9.0-Build29-APK'
OLD_ARTIFACT = 'AGAN-PONSEL-v1.8.0-Build28-APK'
MARKER = '// AGAN_PONSEL_PREMIUM_CASH_CARD_V29'


def replace_once(s: str, old: str, new: str, label: str) -> str:
    count = s.count(old)
    if count != 1:
        raise ValueError(f'{label}: expected one anchor, found {count}')
    return s.replace(old, new, 1)


def patch_cash(s: str) -> str:
    if MARKER in s:
        return s
    import_anchor = "import '../widgets/kit.dart';"
    s = replace_once(s, import_anchor,
        import_anchor + "\nimport '../widgets/premium_cash_card.dart';"
        + "\nimport 'settings/cash_card_settings.dart';", 'cash widget imports')
    start_marker = '/// Private, locally remembered balance visibility.'
    end_marker = 'class CashScreen extends StatefulWidget {'
    if s.count(start_marker) != 1 or s.count(end_marker) != 1:
        raise ValueError('Existing dashboard BalanceCard definition not found')
    start = s.index(start_marker)
    end = s.index(end_marker, start)
    wrapper = '''// AGAN_PONSEL_PREMIUM_CASH_CARD_V29
/// Existing public widget name retained for the dashboard and other callers.
class BalanceCard extends StatelessWidget {
  final VoidCallback onOpen;
  const BalanceCard({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) => PremiumCashCard(
    onOpen: onOpen,
    onCustomize: () => Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const CashCardSettingsScreen())),
  );
}

'''
    s = s[:start] + wrapper + s[end:]
    state_marker = 'class _CashScreenState extends State<CashScreen> {'
    future_marker = '  Future<void> setDailyTarget() async {'
    if s.count(state_marker) != 1 or s.count(future_marker) != 1:
        raise ValueError('CashScreen state header not found')
    start = s.index(state_marker) + len(state_marker)
    end = s.index(future_marker, start)
    state = '''
  late Future<List<Map<String, Object?>>> entries;

  @override
  void initState() { super.initState(); refresh(); }

  void refresh() => setState(() => entries = AppDatabase.cashHistory());

  void showAppearance() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const CashCardSettingsScreen()));
  }

'''
    s = s[:start] + state + s[end:]
    ui_start = '      Container(padding: const EdgeInsets.all(21),'
    ui_end = '      const SizedBox(height: 16),\n      Row(children: ['
    if s.count(ui_start) != 1 or s.count(ui_end) != 1:
        raise ValueError('CashScreen legacy card container anchor not found')
    start = s.index(ui_start, s.index('class _CashScreenState'))
    end = s.index(ui_end, start)
    s = s[:start] + '      PremiumCashCard(onCustomize: showAppearance),\n' + s[end:]
    appbar = '''      IconButton(tooltip: 'Atur target omzet', onPressed: setDailyTarget,
        icon: const Icon(Icons.flag_outlined)),'''
    replacement = appbar + '''
      IconButton(tooltip: 'Pilihan Kartu Premium', onPressed: showAppearance,
        icon: const Icon(Icons.palette_outlined)),'''
    s = replace_once(s, appbar, replacement, 'CashScreen premium style AppBar')
    return s


def patch_others(s: str) -> str:
    imp = "import 'cash_screen.dart';"
    if "import 'settings/cash_card_settings.dart';" not in s:
        s = replace_once(s, imp,
            imp + "\nimport 'settings/cash_card_settings.dart';", 'other screens import')
    menu = "      _MenuItem(icon: Icons.task_alt_rounded,"
    if "title: 'Pilihan Kartu Premium'" not in s:
        add = '''      _MenuItem(icon: Icons.credit_card_rounded,
        color: const Color(0xFF6F66D1),
        title: 'Pilihan Kartu Premium',
        subtitle: 'Delapan desain kartu saldo, gaya ringkas dan privasi',
        onTap: () => open(const CashCardSettingsScreen())),
'''
        s = replace_once(s, menu, add + menu, 'More menu premium card')
    settings_anchor = "      SettingsCard(icon: Icons.cloud_upload_rounded,"
    if "title: 'Desain Kartu Saldo'" not in s:
        add = '''      SettingsCard(icon: Icons.style_rounded, color: const Color(0xFF7355C7),
        title: 'Desain Kartu Saldo',
        subtitle: 'Kartu premium, pilihan warna, ringkas dan visibilitas',
        onTap: () => go(const CashCardSettingsScreen())),
'''
        s = replace_once(s, settings_anchor, add + settings_anchor,
            'Settings menu card style')
    return s


def patch_backup(s: str) -> str:
    if "'cash_card_style'" in s and "'cash_card_density'" in s:
        return s
    anchor = "    'expense_budget_settings',"
    return replace_once(s, anchor,
        anchor + "\n    'cash_card_style', 'cash_card_density',",
        'portable backup presentation keys')


def patch_pubspec(s: str) -> str:
    if NEW_VERSION in s:
        return s
    return replace_once(s, OLD_VERSION, NEW_VERSION, 'Build29 app version')


def patch_legacy_guard(s: str, *, number: int) -> str:
    marker = f'# BUILD29_FORWARD_COMPATIBLE_GUARD_{number}'
    if marker in s:
        return s
    # Older checks must enforce their original feature invariants but should not
    # require a future release to have their old version or artifact filename.
    if number in (26, 27, 28):
        s, n = re.subn(r"'version: 1\.8\.0\+28'\s*,?", '', s)
        if n != 1:
            raise ValueError(f'Build{number}: legacy version check count {n}')
        s, n = re.subn(r"'AGAN-PONSEL-v1\.8\.0-Build28-APK'\s*,?", '', s)
        if n != 1:
            raise ValueError(f'Build{number}: legacy artifact check count {n}')
    minimum = {26: (1,6,0,26), 27: (1,7,0,27), 28: (1,8,0,28)}[number]
    return s + f'''

{marker}
# Minimum release compatibility; future APK releases remain valid.
_version29 = re.search(r'(?m)^version:\\s*(\\d+)\\.(\\d+)\\.(\\d+)\\+(\\d+)',
    Path('pubspec.yaml').read_text())
assert _version29, 'AGAN PONSEL version missing'
assert tuple(map(int, _version29.groups())) >= {minimum}, 'Requires Build{number} or newer'
'''


def patch_workflow(s: str) -> str:
    if NEW_ARTIFACT not in s:
        s = replace_once(s, OLD_ARTIFACT, NEW_ARTIFACT,
            'Build29 GitHub Actions APK artifact')
    if 'scripts/check_build29.py' not in s:
        anchor = '      - name: Analyze Flutter code'
        stage = '''      - name: Validate Build29 premium cash card and settings
        run: |
          python3 scripts/check_build29.py
          python3 scripts/smoke_cash_card_settings.py

'''
        s = replace_once(s, anchor, stage + anchor,
            'Build29 GitHub Actions validation')
    test = 'test/build29_cash_card_test.dart'
    if test not in s:
        anchor = 'test/build28_store_plus_test.dart'
        s = replace_once(s, anchor, anchor + ' ' + test,
            'Build29 Flutter unit test')
    return s


def main() -> None:
    root = Path.cwd()
    spec = root/'pubspec.yaml'
    if not spec.is_file():
        raise SystemExit('Jalankan dari folder utama proyek Flutter AGAN PONSEL')
    version = spec.read_text()
    if NEW_VERSION not in version and OLD_VERSION not in version:
        raise SystemExit('Build29 memerlukan source Build28 (versi 1.8.0+28)')
    for rel in ('lib/widgets/premium_cash_card.dart',
                'lib/screens/settings/cash_card_settings.dart'):
        if not (root/rel).exists():
            raise SystemExit(f'File premium belum diekstrak: {rel}')
    if NEW_VERSION in version:
        targets = [
            'lib/screens/cash_screen.dart', 'lib/screens/others.dart',
            'lib/services/backup_service.dart',
            '.github/workflows/build-apk.yml']
        for rel in targets:
            if not (root/rel).exists():
                raise SystemExit(f'Berkas hilang: {rel}')
        if all(MARKER in (root/'lib/screens/cash_screen.dart').read_text()
            for _ in range(1)) and \
            "'cash_card_style'" in (root/'lib/services/backup_service.dart').read_text() and \
            NEW_ARTIFACT in (root/'.github/workflows/build-apk.yml').read_text():
            print('OK: Build29 sudah terpasang. Tidak ada perubahan berulang.')
            return
        raise SystemExit('Source Build29 tidak lengkap; jangan lanjut push, periksa file aplikasi')

    patches = {
        'lib/screens/cash_screen.dart': patch_cash,
        'lib/screens/others.dart': patch_others,
        'lib/services/backup_service.dart': patch_backup,
        'pubspec.yaml': patch_pubspec,
        'scripts/check_build26.py': lambda x: patch_legacy_guard(x, number=26),
        'scripts/check_build27.py': lambda x: patch_legacy_guard(x, number=27),
        'scripts/check_build28.py': lambda x: patch_legacy_guard(x, number=28),
        '.github/workflows/build-apk.yml': patch_workflow,
    }
    updates = {}
    for rel, transform in patches.items():
        path = root/rel
        if not path.is_file():
            raise SystemExit(f'File proyek tidak ditemukan: {rel}')
        try:
            updates[path] = transform(path.read_text())
        except Exception as ex:
            raise SystemExit(f'Pembaruan dibatalkan pada {rel}: {ex}') from ex
    for path, body in updates.items():
        if path.read_text() != body:
            path.write_text(body)
            print('UPDATED', path.relative_to(root))
    print('OK: AGAN PONSEL Build29 Premium Cash Card terpasang pada source; data SQLite tidak disentuh')


if __name__ == '__main__':
    main()
