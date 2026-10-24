"""Run independent of Flutter SDK: verify Dart format variations & regression failures."""
from backup_compat_check import assert_backup_versions, restore_versions

PREFIX = """class BackupService {
  static const tables = <String>['products'];
  static Future<BackupPreview?> chooseBackup() async {
    final formatOk = [1, 2, 3].contains(payload['formatVersion']);
    if (payload['format'] != 'agan-ponsel-sqlite-json') throw Exception();
    if ("""
SUFFIX = """) throw FormatException();
  }
  static Future<void> restore(BackupPreview backup) async {}
}
"""
LIST = ', '.join(map(str, range(4, 15)))


def fixture(expression, schema=14):
    return f"const backup = {{'databaseVersion': {schema}}};\n" + PREFIX + expression + SUFFIX


def verify(code):
    allowed = assert_backup_versions(code, minimum=14, current=14)
    assert allowed == set(range(4, 15))


# Version list and argument on a single line, as in repository source.
verify(fixture(f"![{LIST}].contains(payload['databaseVersion'])"))
# Dart format may split after `.contains`, insert a trailing comma in args,
# or wrap the version-list itself and keep CRLF endings.
verify(fixture("![\n  " + ",\n  ".join(map(str, range(4, 15)))
               + ",\n].contains(\n  payload['databaseVersion'],\n)"))
verify(fixture(f"![{LIST}].contains(\r\n  payload['databaseVersion'],\r\n)"))
verify(fixture(f'![{LIST}].contains(payload["databaseVersion"])'))

# A test must not pass if an old schema is no longer supported.
try:
    assert_backup_versions(fixture('![4, 5, 6, 7, 9, 10, 11, 12, 13, 14].contains(\n'
                                  "  payload['databaseVersion'],\n)"), minimum=14, current=14)
    raise AssertionError('Missing legacy SQLite v8 was accepted')
except AssertionError as error:
    assert 'tidak mendukung' in str(error), error

# Nor when only an unrelated list (e.g. accepted format versions) remains.
for expression in [
    '[1, 2, 3].contains(payload[\'formatVersion\'])',
    '![4, 5, 6].contains(payload[\'formatVersion\'])',
]:
    try:
        restore_versions(fixture(expression))
        raise AssertionError('Unrelated list incorrectly accepted')
    except AssertionError as error:
        assert 'tidak dapat dikenali' in str(error), error

print('OK: restore-version parser supports dart format multiline, rejects missing versions and unrelated lists')
