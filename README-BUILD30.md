# AGAN PONSEL v2.0.0 Build 30 — Beranda Premium, Navigasi & Face Unlock Android

**Patch khusus untuk repository Build29 (`version: 1.9.0+29`).** Ini bukan source Flutter mandiri dan bukan APK yang telah dikompilasi. Gunakan repository yang sudah dibangun sukses pada Build29. Tidak melakukan migrasi database: SQLite tetap v15.

## Pembaruan

1. **Privasi pengingat piutang:** kartu jatuh tempo dan nominal piutang tidak muncul langsung di Beranda. Pusat Pengingat tetap bisa dibuka melalui tombol lonceng header dan Menu Lainnya → Pusat Pengingat. Pengaturan alarm/notifikasi eksternal tidak dihapus.
2. **Kartu Ringkasan Hari Ini:** lapisan gradasi, kilau halus, kedalaman bayangan, sudut modern dan ikon yang selaras, tanpa mengubah angka omzet, laba, transaksi atau service.
3. **Bottom navigation:** indikator bergerak mulus mengikuti menu yang dipilih, ikon membesar secara halus, label bertransisi, haptic feedback. `IndexedStack` tetap digunakan supaya tab dan posisi scroll tidak dibuat ulang saat berpindah menu.
4. **Menu ikon:** desain pintasan lebih clean menggunakan tema Material 3 dengan aksen dan kedalaman ringan.
5. **Prioritas Scan Wajah Android:** menu baru di Pengaturan → Keamanan & PIN, hanya tersedia bila `local_auth` mendapatkan `BiometricType.face` dari Android, PIN 6 digit sudah aktif dan autentikasi platform sukses. Ketika membuka aplikasi terkunci, dialog biometrik dipanggil sekali; PIN tetap tersedia jika sensor gagal/tidak tersedia.

**Batasan keamanan penting:** Android bisa menampilkan atau menerima sidik jari sebagai alternatif; aplikasi Flutter tidak memilih sensor wajah secara eksklusif. Data/foto/template wajah tetap ditangani Android, bukan aplikasi. Fitur kunci UI **tidak mengenkripsi SQLite atau backup JSON** dan bukan pengganti keamanan perangkat.

## Instalasi di Termux

Buat backup data toko terlebih dahulu, lalu unduh ZIP ke `/sdcard/Download`.

```bash
cd ~/agan-build/agan_ponsel_flutter
grep '^version:' pubspec.yaml
# Harus: version: 1.9.0+29

unzip -o "/sdcard/Download/AGAN-PONSEL-Flutter-v2.0.0-Build30-Patch.zip"
python3 scripts/apply_build30.py
python3 scripts/check_build30.py
python3 scripts/smoke_build30_privacy.py
python3 scripts/selftest_build30_patch.py
git diff --check

git add lib/screens/dashboard.dart lib/widgets/kit.dart lib/widgets/identity.dart \
  lib/services/biometric_security.dart lib/screens/security/pin_screens.dart \
  scripts/check_build29.py scripts/apply_build30.py scripts/check_build30.py \
  scripts/smoke_build30_privacy.py scripts/selftest_build30_patch.py \
  test/build30_ui_security_test.dart pubspec.yaml .github/workflows/build-apk.yml README-BUILD30.md

git commit -m "AGAN PONSEL v2.0.0 Build30 Privacy 3D Motion Face Unlock"
git push origin main
```

Periksa Actions di https://github.com/adelibra23/agan-ponsel-flutter/actions. Setelah sukses, unduh artifact `AGAN-PONSEL-v2.0.0-Build30-APK` lalu **instal sebagai update**. Jangan uninstall aplikasi sebelumnya atau menghapus data aplikasi.

## Mengaktifkan Scan Wajah

1. Di Pengaturan Android, daftarkan Face Unlock yang kompatibel dengan API biometrik untuk aplikasi pihak ketiga.
2. Di AGAN PONSEL → Keamanan & PIN, aktifkan PIN 6 digit.
3. Aktifkan **Buka dengan Biometrik** (jika belum aktif).
4. Aktifkan **Prioritaskan Scan Wajah Android**, lakukan verifikasi pada prompt sistem.
5. Buka kembali aplikasi: saat terkunci akan ditawarkan autentikasi biometrik. Jika gagal, gunakan PIN.

Jika opsi tidak aktif, perangkat belum memaparkan biometrik wajah lewat API Android atau belum dikonfigurasi. Jangan gunakan aplikasi kamera biasa sebagai pengganti biometrik sistem.

## Verifikasi

Sudah diperiksa secara lokal: struktur patch, pengulangan patch, penolakan versi tidak cocok, pengendalian anchor, penyeimbangan delimiter Dart pada komponen baru. **Belum diuji dengan Flutter analyzer/SDK atau APK Android fisik di lingkungan ini.** GitHub Actions akan menjalankan pengujian Flutter dan build release.
