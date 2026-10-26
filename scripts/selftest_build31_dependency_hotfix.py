#!/usr/bin/env python3
"""Tests apply script against controlled Build31 fixtures, including rerun."""
import subprocess
import sys
import tempfile
from pathlib import Path

this = Path(__file__).with_name('apply_build31_dependency_hotfix.py').read_text(encoding='utf-8')

with tempfile.TemporaryDirectory(prefix='agan-build31-') as tmp:
    root = Path(tmp)
    (root / 'scripts').mkdir()
    (root / 'scripts/apply_build31_dependency_hotfix.py').write_text(this, encoding='utf-8')
    pub = root / 'pubspec.yaml'
    guard = root / 'scripts/check_build31.py'
    old_pub = '''name: agan_ponsel\nversion: 2.1.0+31\ndependencies:\n  package_info_plus: ^8.3.1\n  flutter_secure_storage: ^11.2.0\ndependency_overrides:\n  shared_preferences_android: 2.4.28\n'''
    old_guard = '''checks = {'pubspec.yaml': ['version: 2.1.0+31', 'package_info_plus: ^8.3.1']}\n'''
    pub.write_text(old_pub, encoding='utf-8')
    guard.write_text(old_guard, encoding='utf-8')
    for _ in range(2):
        result = subprocess.run([sys.executable, str(root / 'scripts/apply_build31_dependency_hotfix.py')], capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
        assert pub.read_text().count('package_info_plus: ^10.2.2') == 1
        assert guard.read_text().count('package_info_plus: ^10.2.2') == 1
        assert 'shared_preferences_android: 2.4.28' in pub.read_text()
    # Reject wrong build before either file is modified.
    pub.write_text(old_pub.replace('2.1.0+31', '2.0.0+30'), encoding='utf-8')
    guard.write_text(old_guard, encoding='utf-8')
    result = subprocess.run([sys.executable, str(root / 'scripts/apply_build31_dependency_hotfix.py')], capture_output=True, text=True)
    assert result.returncode != 0
    assert pub.read_text() == old_pub.replace('2.1.0+31', '2.0.0+30')
    assert guard.read_text() == old_guard
    # Reject mismatch in second file without modifying first.
    pub.write_text(old_pub, encoding='utf-8')
    guard.write_text('some unrelated content', encoding='utf-8')
    result = subprocess.run([sys.executable, str(root / 'scripts/apply_build31_dependency_hotfix.py')], capture_output=True, text=True)
    assert result.returncode != 0
    assert pub.read_text() == old_pub
print('PASS: first apply, repeated apply, wrong version, and drift rejection.')
