# AGAN PONSEL Flutter v2.1.0 Build 31

**Basis:** repository `adelibra23/agan-ponsel-flutter` dengan source `2.0.0+30` (GitHub Actions run #39 sukses).  **Jenis:** patch, bukan source proyek lengkap atau APK.

## Yang baru

1. Animasi isi tab utama: fade/slide/scale selama 320 ms setiap kali beralih Beranda, Kasir, Produk, Service, atau Menu. `IndexedStack` **tetap ada**; tab tidak dilepas dan posisi scroll/perjalanan form di tiap tab tetap terjaga.
2. Halaman **Tentang AGAN PONSEL** diganti profil toko modern dengan logo yang tersimpan, nama usaha, deskripsi, jam operasional, alamat, serta informasi versi **yang dibaca dari APK** dengan `package_info_plus`.
3. **Sunting Profil Toko**: ubah nama, deskripsi, jam, alamat, telepon, WhatsApp, email, Instagram, situs web. Informasi kontak kosong tidak diisi otomatis dengan nomor palsu.
4. Tombol **Salin Kontak**, **Bagikan** (Android Sharesheet), dan tautan kontak untuk panggilan telepon, WhatsApp, email, Instagram, dan URL HTTPS. WhatsApp/telepon/email dibuka atas tindakan pengguna; tidak mengirim pesan otomatis.
5. Kontak publik toko ikut di-backup melalui profil aplikasi. PIN, preferensi biometrik, dan status tampil/sembunyi saldo **tidak** dimasukkan dalam backup. SQLite tetap **v15**.
6. Skrip pengujian versi Build29/30 dan nama artifact workflow otomatis diperbarui agar tidak menolak versi Build31.

## Instal melalui Termux (dari Build30)

Sebelumnya buat **backup data toko**. Jangan uninstall APK lama atau lakukan clear data.

Simpan `AGAN-PONSEL-Flutter-v2.1.0-Build31-Patch.zip` ke folder `Download` pada Android, lalu:

```bash
cd ~/agan-build/agan_ponsel_flutter

grep '^version:' pubspec.yaml
# Harus version: 2.0.0+30

unzip -o "/sdcard/Download/AGAN-PONSEL-Flutter-v2.1.0-Build31-Patch.zip"

python3 scripts/apply_build31.py
python3 scripts/check_build31.py
python3 scripts/smoke_build31_about_backup.py
python3 scripts/selftest_build31_patch.py
git diff --check
```

Setelah pemeriksaan berhasil:

```bash
git add lib scripts test pubspec.yaml .github/workflows/build-apk.yml README-BUILD31.md
git commit -m "AGAN PONSEL v2.1.0 Build31 Animated Tabs About Contacts"
git push origin main
```

Lalu buka https://github.com/adelibra23/agan-ponsel-flutter/actions dan tunggu workflow Flutter. APK unduhan hasil build GitHub Actions bernama `AGAN-PONSEL-v2.1.0-Build31-APK` jika semua tahapan lulus.

## Memakai fitur

- **Animasi tab:** buka navigasi bawah dan pindah di antara lima tab. Animasi isi berjalan secara singkat dan tidak mereset posisi halaman.
- **Kontak & deskripsi:** `Menu Lainnya → Pengaturan → Tentang Aplikasi → Sunting`. Isi hanya nomor dan tautan yang benar-benar dimiliki AGAN PONSEL.
- **Versi aplikasi:** terbaca otomatis dari metadata APK, bukan tulisan versi lama yang dikunci.
- **Bagikan:** lihat halaman Tentang dan pilih `Bagikan` (atau salin teks). Pengguna memilih aplikasi/penerima sendiri.

## Pengujian & batasan

- Source patch diuji pada fixture yang meniru anchor Build30; patch dapat dijalankan ulang, dan gagal sebelum mengubah file bila source tidak cocok.
- Fungsi backup diperiksa secara statis, SQLite v15 tetap dipertahankan.
- Karena SDK Flutter/Dart tidak tersedia di lingkungan pembuatan patch, **Flutter Analyze, unit test Dart, dan APK release belum dijalankan**. Hasil GitHub Actions perlu diperiksa sebelum instalasi.
- Untuk kompatibilitas Gradle proyek saat ini, `package_info_plus` dipasang pada rentang versi mayor 8 (`^8.3.1`) bukan versi mayor baru yang menaikkan persyaratan Android Gradle Plugin.
- Fitur backup Google Drive dan AI online tetap memerlukan konfigurasi koneksi dan akses internet masing-masing.
