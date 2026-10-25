#!/usr/bin/env python3
"""Repeatability / preflight failure behavior for Build31 upgrade script."""
from pathlib import Path
from tempfile import TemporaryDirectory
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
APPLY = ROOT / 'scripts/apply_build31.py'

fixtures = {
    'lib/main.dart': '''class _AppShellState extends State<AppShell> {
  int selected = 0;
  void select(int tab) {
    if (tab != selected) setState(() => selected = tab);
  }
  Widget build(BuildContext context) => Column(children: [Expanded(child: IndexedStack(index: selected, children: pages)),]);
}
''',
    'lib/screens/settings/settings_pages.dart': '''import '../../widgets/store_logo.dart';
class AboutAganScreen extends StatelessWidget {
  const AboutAganScreen({super.key});
  Widget build(BuildContext context) => Text('Flutter • v1.1.0 Build 21');
}
class StoreBrandSettingsScreen extends StatefulWidget {}
''',
    'lib/services/backup_service.dart': '''  static const profileKeys = [
    'local_shop_name', 'local_shop_address', 'local_receipt_footer',
    'daily_sales_target',
  ];
''',
    'pubspec.yaml': '''name: agan_ponsel
version: 2.0.0+30
dependencies:
  shared_preferences: ^2.5.3
''',
    '.github/workflows/build-apk.yml': '''name: Build APK
    run: flutter test test/build30_ui_security_test.dart
      - name: Analyze Flutter code
        run: flutter analyze
name: AGAN-PONSEL-v2.0.0-Build30-APK
''',
    'scripts/check_build29.py': '''version: 2.0.0+30
AGAN-PONSEL-v2.0.0-Build30-APK
''',
    'scripts/check_build30.py': '''version: 2.0.0+30
AGAN-PONSEL-v2.0.0-Build30-APK
version: 2.0.0+30
AGAN-PONSEL-v2.0.0-Build30-APK
''',
}


def setup(dest: Path):
    for name, content in fixtures.items():
        path = dest / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    for name in ['lib/screens/settings/about_store.dart',
                 'lib/services/store_about_profile.dart',
                 'scripts/check_build31.py', 'test/build31_about_test.dart']:
        target = dest / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)


def run(dest: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(APPLY)], cwd=dest,
                          capture_output=True, text=True)


with TemporaryDirectory() as td:
    tmp = Path(td)
    setup(tmp)
    result = run(tmp)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'version: 2.1.0+31' in (tmp / 'pubspec.yaml').read_text()
    assert 'BUILD31_TAB_CONTENT_MOTION' in (tmp / 'lib/main.dart').read_text()
    assert 'BUILD31_ABOUT_WRAPPER' in (
        tmp / 'lib/screens/settings/settings_pages.dart').read_text()
    before = {name: (tmp / name).read_bytes() for name in fixtures}
    repeated = run(tmp)
    assert repeated.returncode == 0, repeated.stdout + repeated.stderr
    assert all((tmp / name).read_bytes() == blob for name, blob in before.items())

with TemporaryDirectory() as td:
    tmp = Path(td)
    setup(tmp)
    target = tmp / 'lib/main.dart'
    target.write_text(target.read_text().replace(
        'Expanded(child: IndexedStack(index: selected, children: pages)),',
        'Expanded(child: UnknownTabWidget()),'))
    before = {name: (tmp / name).read_bytes() for name in fixtures}
    result = run(tmp)
    assert result.returncode != 0, 'Missing source anchor must be rejected'
    assert all((tmp / name).read_bytes() == blob for name, blob in before.items()), (
        'Invalid source must be rejected before touching tracked files')

with TemporaryDirectory() as td:
    tmp = Path(td)
    setup(tmp)
    pubspec = tmp / 'pubspec.yaml'
    pubspec.write_text(pubspec.read_text().replace('2.0.0+30', '1.9.0+29'))
    before = {name: (tmp / name).read_bytes() for name in fixtures}
    result = run(tmp)
    assert result.returncode != 0, 'Wrong version must be rejected'
    assert all((tmp / name).read_bytes() == blob for name, blob in before.items())

print('OK: Build31 patch repeats safely and rejects wrong versions/source anchors')
