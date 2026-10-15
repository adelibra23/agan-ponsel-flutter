"""Keep the literal word 'offline' only in the About Aplikasi screen."""
from pathlib import Path

root = Path('lib')
about_file = Path('lib/screens/settings/settings_pages.dart')
for path in root.rglob('*.dart'):
    source = path.read_text()
    if path == about_file:
        if 'class AboutAganScreen' not in source or 'class StoreBrandSettingsScreen' not in source:
            raise SystemExit('About Aplikasi section could not be located')
        first, tail = source.split('class AboutAganScreen', 1)
        about, last = tail.split('class StoreBrandSettingsScreen', 1)
        check = first + last
        if 'offline' in check.lower():
            raise SystemExit(f'Forbidden label outside About: {path}')
        if 'offline' not in about.lower():
            raise SystemExit('About Aplikasi should explain local/offline behavior')
    elif 'offline' in source.lower():
        raise SystemExit(f'Forbidden label: {path}')
print('OK: kata offline hanya di Tentang Aplikasi')
