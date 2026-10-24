"""Shared CI-only verification for legacy AGAN PONSEL backups.

Dart's formatter can break lines after `.contains(` and can add a trailing
comma to the argument.  Verify the literal restore allowlist without depending
on formatting.  This module never modifies user data or the app database.
"""
from __future__ import annotations

import re


_ALLOWLIST = re.compile(
    r"!\s*\[\s*(?P<versions>\d+(?:\s*,\s*\d+)*\s*,?)\s*\]"
    r"\s*\.\s*contains\s*\(\s*payload\s*\[\s*"
    r"['\"]databaseVersion['\"]\s*\]\s*,?\s*\)",
    re.S,
)


def restore_versions(backup_dart: str) -> set[int]:
    """Read the literal version allowlist used by BackupService.chooseBackup()."""
    # Limit scanning to the restore validation method, not unrelated arrays.
    section_start = backup_dart.find('static Future<BackupPreview?> chooseBackup()')
    if section_start == -1:
        raise AssertionError('Metode chooseBackup tidak ditemukan')
    section_end = backup_dart.find('static Future<void> restore(', section_start)
    if section_end == -1:
        raise AssertionError('Metode restore tidak ditemukan')
    section = backup_dart[section_start:section_end]
    match = _ALLOWLIST.search(section)
    if match is None:
        raise AssertionError('Daftar versi backup yang didukung tidak dapat dikenali')
    values = [int(part.strip()) for part in match['versions'].split(',') if part.strip()]
    if len(values) != len(set(values)):
        raise AssertionError('Daftar versi backup memiliki nomor duplikat')
    return set(values)


def assert_backup_versions(backup_dart: str, *, minimum: int, current: int) -> set[int]:
    """Require *all* legacy versions from 4 through the current database schema."""
    schema = re.search(r"['\"]databaseVersion['\"]\s*:\s*(\d+)", backup_dart)
    if not schema or int(schema.group(1)) != current:
        raise AssertionError(f'Versi metadata backup harus {current}')
    supported = restore_versions(backup_dart)
    expected = set(range(4, current + 1))
    missing = sorted(expected.difference(supported))
    if missing:
        raise AssertionError(f'Backup tidak mendukung SQLite versi: {missing}')
    if current < minimum:
        raise AssertionError(f'Versi database harus minimal {minimum}')
    return supported
