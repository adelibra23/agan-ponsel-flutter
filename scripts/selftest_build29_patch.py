#!/usr/bin/env python3
"""Check stable transformations, repeated invocation, rollback on wrong source."""
from pathlib import Path
import importlib.util
import tempfile
import zipfile

source = Path(__file__).resolve().parent/'apply_build29.py'
spec = importlib.util.spec_from_file_location('agan_build29_patch', source)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

# Build17 preserved the public cash widgets still present in Build28. This
# fixture is sufficient for testing the exact swap anchors and output structure.
archive = Path('/mnt/data/AGAN-PONSEL-Flutter-v1.0.0-Build17.zip')
if archive.exists():
    with zipfile.ZipFile(archive) as z:
        old = z.read('lib/screens/cash_screen.dart').decode()
else:
    old = """import '../widgets/kit.dart';
/// Private, locally remembered balance visibility.
class BalanceCard extends StatelessWidget {}
class CashScreen extends StatefulWidget {}
class _CashScreenState extends State<CashScreen> {
  void refresh() {}
  Future<void> setDailyTarget() async {}
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dompet Kas Toko'), actions: [
      IconButton(tooltip: 'Atur target omzet', onPressed: setDailyTarget,
        icon: const Icon(Icons.flag_outlined)),
    ]),
    body: ListView(children: [
      Container(padding: const EdgeInsets.all(21),
        child: Text('legacy card')),
      const SizedBox(height: 16),
      Row(children: [Text('test')]),
    ]),
  );
}
"""
patched = module.patch_cash(old)
assert module.MARKER in patched
assert 'PremiumCashCard(onCustomize: showAppearance)' in patched
assert 'class BalanceCard extends StatelessWidget' in patched
assert 'CashCardSettingsScreen' in patched
assert module.patch_cash(patched) == patched

other = """import 'cash_screen.dart';
      _MenuItem(icon: Icons.task_alt_rounded,
      SettingsCard(icon: Icons.cloud_upload_rounded,
"""
other_patch = module.patch_others(other)
assert 'Desain Kartu Saldo' in other_patch and 'Pilihan Kartu Premium' in other_patch
assert module.patch_others(other_patch) == other_patch

backup = "    'expense_budget_settings',\n"
bkp = module.patch_backup(backup)
assert "'cash_card_style', 'cash_card_density'" in bkp
assert module.patch_backup(bkp) == bkp

for n in (26, 27, 28):
    old_guard = "from pathlib import Path\nimport re\nchecks={'pubspec.yaml':['version: 1.8.0+28', 'shared_preferences_android: 2.4.28'], '.github/workflows/build-apk.yml':['AGAN-PONSEL-v1.8.0-Build28-APK', 'test/build28_store_plus_test.dart']}\n"
    future = module.patch_legacy_guard(old_guard, number=n)
    assert "'version: 1.8.0+28'" not in future
    assert "'AGAN-PONSEL-v1.8.0-Build28-APK'" not in future
    compile(future, f'Build{n} forward guard', 'exec')
    assert module.patch_legacy_guard(future, number=n) == future

workflow = """      - name: Analyze Flutter code
        run: flutter analyze --no-fatal-infos --no-fatal-warnings
      - name: Run basic unit tests
        run: flutter test test/build28_store_plus_test.dart
      - name: Upload installable APK artifact
        with:
          name: AGAN-PONSEL-v1.8.0-Build28-APK
"""
wf = module.patch_workflow(workflow)
assert 'AGAN-PONSEL-v1.9.0-Build29-APK' in wf
assert 'test/build29_cash_card_test.dart' in wf
assert 'scripts/smoke_cash_card_settings.py' in wf
assert module.patch_workflow(wf) == wf
assert module.patch_pubspec('version: 1.8.0+28\n') == 'version: 1.9.0+29\n'

try:
    module.patch_cash('class BadCashState {}')
except ValueError:
    pass
else:
    raise AssertionError('Wrong source must abort, not produce partial upgrade')

print('PASS: Build29 premium cash patch anchors, repeat safety and legacy CI guards')
