#!/usr/bin/env python3
"""Safely update the Build31 About copy and its relocated copy guard.

Does not edit SQLite, backup, PIN, or profile fields. Idempotent.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
ABOUT = ROOT / 'lib/screens/settings/about_store.dart'
WRAPPER = ROOT / 'lib/screens/settings/settings_pages.dart'
GUARD = ROOT / 'scripts/check_labels.py'
PUBSPEC = ROOT / 'pubspec.yaml'

OLD = """                            Text('Kelola penjualan, produk, service, piutang, '
                              'pengeluaran, laporan dan stok dalam satu aplikasi. '
                              'Data transaksi utama tersimpan di perangkat. '
                              'Fitur backup Google Drive serta AGANA online '
                              'memerlukan konfigurasi dan akses internet.',
                              style: TextStyle(height: 1.45)),"""
NEW = """                            Text('Kelola penjualan, produk, service, piutang, '
                              'pengeluaran, laporan dan stok dalam satu aplikasi. '
                              'Pencatatan utama dapat digunakan secara offline '
                              'dan data transaksi tersimpan lokal di perangkat. '
                              'Backup Google Drive, AGANA berbasis API, dan '
                              'layanan WhatsApp memerlukan akses internet '
                              'serta pengaturan yang sesuai.',
                              style: TextStyle(height: 1.45)),"""

# The Build31 About route changed from inline UI in settings_pages.dart to
# AboutStoreScreen in about_store.dart. Only the About section can say offline.
FIXED_GUARD = '''"""Limit the literal word "offline" to the visible About Aplikasi section.

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
'''


def main():
    if not (ABOUT.is_file() and WRAPPER.is_file() and GUARD.is_file() and PUBSPEC.is_file()):
        raise SystemExit('Source Flutter Build31 tidak lengkap; tidak ada file yang diubah')
    version = re.search(r'(?m)^version:\s*([^\s]+)', PUBSPEC.read_text(encoding='utf-8'))
    if version is None or version.group(1) != '2.1.0+31':
        raise SystemExit('Hotfix hanya untuk AGAN PONSEL v2.1.0 Build31')
    wrapper = WRAPPER.read_text(encoding='utf-8')
    if 'class AboutAganScreen' not in wrapper or 'AboutStoreScreen()' not in wrapper:
        raise SystemExit('Rute AboutStoreScreen tidak ditemukan; tidak ada file yang diubah')
    about = ABOUT.read_text(encoding='utf-8')
    if about.count(OLD) == 1:
        updated = about.replace(OLD, NEW, 1)
    elif about.count(NEW) == 1:
        updated = about
    else:
        raise SystemExit('Teks sumber About Build31 berubah; tidak ada file yang diubah')
    # Validate both changes before writing anything.
    if updated.count("const _AboutSectionTitle('Tentang Aplikasi'),") != 1:
        raise SystemExit('Bagian Tentang Aplikasi tidak cocok; tidak ada file yang diubah')
    if updated.count('offline') != 1:
        raise SystemExit('Label offline duplikat/berubah; tidak ada file yang diubah')
    # Do not drop old guard invariants; the replacement checks every Dart file.
    if 'offline' not in GUARD.read_text(encoding='utf-8').lower():
        raise SystemExit('Guard asli tidak dikenal; tidak ada file yang diubah')
    if updated != about:
        ABOUT.write_text(updated, encoding='utf-8')
    if GUARD.read_text(encoding='utf-8') != FIXED_GUARD:
        GUARD.write_text(FIXED_GUARD, encoding='utf-8')
    print('PASS: Build31 About local/offline explanation and location-aware label guard')


if __name__ == '__main__':
    main()
