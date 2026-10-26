"""Limit the literal word "offline" to the visible About Aplikasi section.

Build31 moved its content into about_store.dart; test the actual destination,
not the AboutAganScreen compatibility wrapper in settings_pages.dart.
"""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
lib = root / 'lib'
wrapper = lib / 'screens/settings/settings_pages.dart'
about_file = lib / 'screens/settings/about_store.dart'
if not wrapper.is_file() or not about_file.is_file():
    raise SystemExit('Halaman Tentang Build31 tidak ditemukan')
wrapper_text = wrapper.read_text(encoding='utf-8')
if 'class AboutAganScreen' not in wrapper_text or 'AboutStoreScreen()' not in wrapper_text:
    raise SystemExit('Rute Tentang tidak mengarah ke AboutStoreScreen')
source = about_file.read_text(encoding='utf-8')
section_start = "const _AboutSectionTitle('Tentang Aplikasi'),"
section_end = 'const SizedBox(height: 14),'
if source.count(section_start) != 1:
    raise SystemExit('Bagian Tentang Aplikasi tidak ditemukan secara unik')
left, rest = source.split(section_start, 1)
if section_end not in rest:
    raise SystemExit('Batas bagian Tentang Aplikasi tidak ditemukan')
about, right = rest.split(section_end, 1)
if 'offline' not in about.lower():
    raise SystemExit('About Aplikasi harus menjelaskan penggunaan offline/lokal')
if 'offline' in left.lower() or 'offline' in right.lower():
    raise SystemExit('Kata offline hanya boleh tampil dalam bagian Tentang Aplikasi')
for path in lib.rglob('*.dart'):
    if path == about_file:
        continue
    if 'offline' in path.read_text(encoding='utf-8').lower():
        raise SystemExit(f'Label offline tidak boleh di luar Tentang Aplikasi: {path}')
print('OK: kata offline hanya ada dalam Tentang Aplikasi Build31')
