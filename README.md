# AGAN PONSEL — Flutter Offline v0.4.0 Build 5

Aplikasi Android berbasis **Dart + Flutter** dengan database lokal **SQLite**. Source code ini melanjutkan versi 0.3.0 dan menggunakan desain AG Orbit (header biru dengan animasi) serta navigasi bawah modern.

## Fitur pada source

- Dashboard, penjualan keranjang multi-produk, diskon, metode pembayaran, struk dan riwayat penjualan.
- Produk, kategori, SKU, stok minimum, catatan pergerakan stok.
- **Service Baru** dalam 3 tab: Pelanggan, Perangkat, Biaya & Jadwal.
- Detail Service: IMEI, aksesoris yang ditinggalkan, kondisi perangkat, teknisi, prioritas, estimasi, DP/pelunasan, target selesai, garansi dan riwayat status.
- **Backup & Restore data SQLite** berupa snapshot JSON yang disimpan di lokasi pilihan pengguna dengan checksum SHA-256, pratinjau data, dan konfirmasi sebelum overwrite. Restore dijalankan dalam transaksi SQLite (gagal => rollback).
- **Printer thermal Bluetooth Classic ESC/POS** (umumnya 58 mm/80 mm). Daftar printer yang sudah dipasangkan, koneksi, ukuran kertas, test print, struk penjualan dan tiket service. Membutuhkan permission Bluetooth pada Android 12+.
- **Pengaturan akun lokal** (nama pengelola, telepon, email, nama/alamat toko, footer struk), tema, informasi SQLite (jumlah baris, integritas), Tentang Aplikasi.
- Pencatatan offline transaksi pulsa/topup/transfer (tidak mengeksekusi transaksi eksternal secara nyata).

## Privasi data dan peringatan penting

1. Backup adalah **ekspor JSON dari seluruh tabel SQLite**, bukan file mentah `.db` (lebih portabel untuk import). Backup mengandung data pelanggan, IMEI, dan transaksi **dalam teks biasa tanpa enkripsi**. Simpan di penyimpanan yang dipercaya dan jangan bagikan sembarangan. SHA-256 hanya untuk memeriksa kesalahan/perubahan isi, bukan perlindungan dari orang yang mengubah file dengan sengaja.
2. Restore secara sengaja **mengganti semua data toko pada Android ini**. Ekspor backup terkini terlebih dahulu; lalu pilih file backup, tinjau, dan ketik `PULIHKAN`. Jika impor gagal saat transaksi SQLite, data sebelumnya tidak akan terhapus secara parsial.
3. **Jangan uninstall atau Clear storage** tanpa memiliki backup yang sudah diuji. Data SQLite di penyimpanan privat aplikasi bisa hilang saat aplikasi dihapus.
4. Pada workflow ini, `flutter build apk --release` menggunakan penandatanganan standar proyek Flutter yang dibuat saat build. **Jangan menganggap APK GitHub dari run yang berbeda bisa saling memperbarui** tanpa keystore rilis permanen yang sama. Android menolak update APK dengan signature yang berbeda. Siapkan release signing permanen sebelum penggunaan produksi dan sebelum menaruh data toko penting di aplikasi.
5. Printer harus berpasangan lewat menu Bluetooth Android terlebih dahulu dan memakai **Bluetooth Classic/Serial Port Profile + ESC/POS**. Tidak semua printer Bluetooth kompatibel; uji pada printer dan Android sebenarnya. Tidak ada jaminan cetak pada semua model.
6. Pengaturan akun ini adalah **profil lokal**, bukan autentikasi cloud atau sistem multi-kasir. Fitur PIN/pemisahan akses akun belum tersedia di Build 5.
7. Fitur dibuat tetapi **belum diuji berhasil dikompilasi sebagai APK maupun diuji pada printer sungguhan** dalam lingkungan pengembangan. Verifikasi pada GitHub Actions dan HP sebelum dipakai di toko.

## Build dari Termux + GitHub Actions

Unduh `AGAN-PONSEL-Flutter-v0.4.0-Build5.zip` dan simpan di **Download** Android. Lalu jalankan:

```bash
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v0.4.0-Build5.zip

git add lib pubspec.yaml README.md .github/workflows/build-apk.yml scripts test

git commit -m "AGAN PONSEL Flutter v0.4.0 Build5"
git push origin main
```

GitHub Actions akan menjalankan:

1. `flutter create --platforms=android --project-name agan_ponsel .`
2. `python3 scripts/prepare_android.py` — menambahkan izin Bluetooth dan menghapus pengujian counter default yang salah.
3. `flutter pub get`, `dart format lib test`, `flutter analyze`.
4. `flutter test test/format_test.dart`.
5. `flutter build apk --release` dan upload artifact `AGAN-PONSEL-v0.4.0-Build5-APK`.

Jika build berhasil, unduh ZIP artifact dari tab **Actions** dan ekstrak file `app-release.apk` sebelum instal. Jika gagal, baca error di job `Flutter Android APK`.

## Build di PC (alternatif)

Syarat: Flutter SDK, Android SDK, JDK 17. Pada folder source:

```bash
flutter create --platforms=android --project-name agan_ponsel .
python3 scripts/prepare_android.py
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test test/format_test.dart
flutter build apk --release
```

## Penyimpanan dan migrasi

Nama database lokal tetap `agan_ponsel_v1.db`, sehingga SQLite lama versi 1/2/3 dapat **dimigrasikan ke skema v4**, termasuk kolom penerimaan service dan tabel `service_events`. Migrasi hanya berjalan jika data aplikasi lama masih ada dan aplikasi baru memiliki **package name serta signature yang kompatibel**. Skema database tidak direset saat upgrade. Migrasi tidak menjamin pemulihan jika APK sebelumnya di-uninstall.

## Tautan

Repository GitHub pengguna: `https://github.com/adelibra23/agan-ponsel-flutter`

Informasi paket: https://pub.dev/packages/file_picker, https://pub.dev/packages/print_bluetooth_thermal, https://pub.dev/packages/permission_handler.
