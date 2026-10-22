# AGAN PONSEL Flutter v1.3.0 Build 23 — Backup Google Drive & Alarm Piutang

Patch untuk repository **Build22** (`version: 1.2.0+22`), yang sudah mempunyai AGANA WhatsApp dan hotfix shared_preferences_android 2.4.28.
Jangan diterapkan ke Build17/18/19 lama atau ke aplikasi yang datanya belum dibackup.

## Fitur

1. **Backup otomatis ke Google Drive**: buat file JSON SHA-256 yang identik dengan ekspor lokal dalam folder Drive khusus aplikasi. Scope `https://www.googleapis.com/auth/drive.file`. Frekuensi harian/mingguan/bulanan, jam pilihan, Wi-Fi saja/semua jaringan, retensi 7/14/30 file. Tombol Backup Sekarang dan informasi sukses/gagal.
2. **Alarm piutang**: pemberitahuan Android dengan suara/getar untuk piutang belum lunas: 3 hari sebelum, 1 hari sebelum, hari jatuh tempo, dan terlambat. Ringkasan, bukan nama atau nomor pelanggan, maksimal satu notifikasi per tanggal. Pengaturan aktif/nonaktif dan jam.
3. **Android WorkManager**: memeriksa kedua tugas secara berkala ketika aplikasi tidak sedang aktif. Bukan penjadwalan jam yang presisi; Android bisa menunda atau menghentikan aktivitas latar belakang, khususnya akibat optimasi baterai. Saat tidak ada Wi-Fi, backup mode Wi-Fi-saja tertunda. Jika izin OAuth tidak dapat disegarkan tanpa UI, backup gagal dan ada pesan untuk menghubungkan ulang akun.
4. **Integrasi**: halaman baru dalam Menu Lainnya dan Pengaturan, tanpa menghapus kasir/service/nota/AGANA atau mereset PIN. SQLite tetap **v11** dan tidak dimigrasikan ulang.

## Cara instal di Termux (di folder repo Build22 yang telah berjalan)

Unduh `AGAN-PONSEL-Flutter-v1.3.0-Build23-Patch.zip` dan simpan di Download HP.

```sh
cd ~/agan-build/agan_ponsel_flutter
# Buat cadangan source; data SQLite ADA DI DALAM APLIKASI dan harus di-backup secara terpisah.
git status --short
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.3.0-Build23-Patch.zip
python3 scripts/upgrade_build23.py
python3 scripts/check_build23.py
python3 scripts/smoke_receivable_v11.py

git add lib/services/backup_service.dart lib/services/drive_backup_service.dart lib/services/debt_alarm_service.dart lib/services/background_jobs.dart lib/screens/settings/drive_backup_settings.dart lib/screens/settings/debt_alarm_settings.dart scripts/upgrade_build23.py scripts/check_build23.py scripts/prepare_android.py test/build23_schedule_test.dart lib/main.dart lib/screens/others.dart pubspec.yaml .github/workflows/build-apk.yml README.md CHANGELOG.md README-BUILD23.md

git commit -m "AGAN PONSEL v1.3.0 Build23 Google Drive dan Alarm Piutang"
git push origin main
```

Periksa: https://github.com/adelibra23/agan-ponsel-flutter/actions
Nama artifact jika build sukses: `AGAN-PONSEL-v1.3.0-Build23-APK`.

## MENGHUBUNGKAN GOOGLE CLOUD (dibutuhkan agar Google Sign-In dapat bekerja)

1. Buka **https://console.cloud.google.com**. Pilih/buat project Google Cloud.
2. Aktifkan **Google Drive API** di APIs & Services → Library.
3. Siapkan **OAuth consent screen** dan daftarkan scope `.../auth/drive.file`. Saat aplikasi masih dalam testing, tambahkan akun Google toko sebagai test user. Publishing/verifikasi OAuth bisa memerlukan langkah Google sesuai penggunaan.
4. Buat OAuth Client ID jenis **Android** yang menggunakan **applicationId paket APK AGAN PONSEL** dan sidik jari **SHA-1 dari signing certificate yang benar-benar dipakai untuk APK yang terpasang**. JANGAN memakai SHA dari debug keystore lain. Jika GitHub Actions mengganti signing key antar build, konfigurasi login/upgrade tidak akan stabil; set keystore release permanen terlebih dahulu.
5. Buat OAuth Client ID jenis **Web application** di project Google Cloud yang sama.
6. Di aplikasi AGAN PONSEL → Menu Lainnya → Google Drive Otomatis, tempel **Web Client ID** (umumnya berakhiran `.apps.googleusercontent.com`) lalu klik **Hubungkan Akun Google**. Izinkan scope Drive yang diminta, kemudian coba **Backup ke Drive Sekarang** dan periksa file di Drive.
7. Aktifkan jadwal serta batas Wi-Fi, lalu **Simpan Jadwal**. Cek Status Backup secara berkala. Pengguna bisa mencabut akses melalui akun Google.

**Web client ID bukan API key atau client secret. Jangan tempel client secret / private key ke aplikasi.**

## Mengatur alarm

Menu Lainnya → Alarm Jatuh Tempo → aktifkan → pilih jam, 3 hari/1 hari/hari H/terlambat → **Simpan & Izinkan Notifikasi**. Android 13+ memerlukan izin notifikasi. Pastikan perangkat tidak memblokir notifikasi atau mode suara. Tombol **Periksa Tagihan Sekarang** menguji dari data SQLite nyata, tetapi hanya mengirim bila ada piutang yang memenuhi kategori.

## Keamanan dan batasan

- Backup Google Drive **tidak terenkripsi**: JSON berisi data toko dan pelanggan. Lingkup `drive.file` hanya file yang dibuat/diizinkan untuk aplikasi, bukan seluruh Drive. Pastikan akun Google toko dilindungi 2FA.
- Tidak ada upload ketika pengguna belum mengizinkan atau jadwal dimatikan. Backup Sekarang merupakan tindakan eksplisit.
- Android WorkManager tidak menjanjikan eksekusi persis di jam target. Alarm ini memakai notifikasi suara/getar Android, **bukan** alarm full-screen dengan `SCHEDULE_EXACT_ALARM`.
- Auto-backup tetap **membutuhkan login pertama lewat UI**, OAuth Android+Web dikonfigurasi, akses internet, dan izin Drive aktif. Beberapa versi Android/Google Sign-In dapat menolak pemulihan token dalam proses headless; aplikasi merekam kegagalan, bukan mengklaim backup sukses. Karena itu cadangan manual berkala tetap diperlukan.
- Jangan uninstall aplikasi, hapus data, ganti applicationId atau signing key. Semua piutang lama tetap ada jika update benar-benar dipasang di atas APK lama dan data tidak dihapus.

## Pengujian

- `scripts/upgrade_build23.py` dirancang idempoten dan menolak proyek di luar Build22.
- `scripts/check_build23.py` memvalidasi berkas integrasi, dependensi, navigasi, dan hotfix.
- `test/build23_schedule_test.dart` memeriksa logika harian, mingguan, bulanan, batas jam, dan jadwal yang dimatikan.
- Smoke test SQLite v11 yang sudah ada dalam proyek tetap dieksekusi pada workflow.
- **Tidak dikompilasi dengan Flutter SDK di lingkungan penyiapan ZIP ini**. Kompilasi GitHub Actions dan pengujian login, WorkManager, izin notifikasi, dan perilaku HP asli tetap wajib dilakukan.
