# AGAN PONSEL Flutter v1.1.0 Build 21 — AGANA WhatsApp

## Instal source pembaruan melalui Termux HP

Paket ini adalah **UPDATE (overlay)** untuk proyek lokal Build 20 yang sudah ada, bukan source Flutter penuh. Jangan hapus/rename folder proyek atau database Android.

Simpan ZIP di folder Download HP, jalankan:

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.1.0-Build21-WhatsApp-Agent.zip
git add lib pubspec.yaml scripts README.md CHANGELOG.md INSTALL-TERMUX.txt whatsapp-agent-server .github/workflows/build-apk.yml
git commit -m "AGAN PONSEL v1.1.0 Build21 AGANA WhatsApp"
git push origin main
```

Lihat hasil APK di GitHub Actions repository. Tanda centang hijau memastikan proses build selesai, **bukan** WhatsApp live berfungsi. Jangan uninstall APK atau hapus data sebelum punya backup. Pastikan update APK memakai signature yang sama agar SQLite dan PIN tidak hilang.

## Cara memakai API key AGANA Android

Masuk **Pengaturan → AGANA Pengaturan API**. Pilih penyedia AI, tempel API key, **Simpan**. Ketika halaman dibuka lagi, API key yang tersimpan akan terlihat sebagai titik (`•••`) pada kolom. Tekan ikon **mata** jika ingin memeriksanya. **Hapus API Key** menghapus dari Android. Kunci disimpan via `flutter_secure_storage` dan tidak dimasukkan ke backup.

## Cara mengaktifkan balasan otomatis WhatsApp

**Bukan fitur yang bisa langsung diaktifkan hanya dengan menginstal APK.** Agar pesan masuk ke nomor toko dibalas otomatis, nomor perlu dihubungkan melalui WhatsApp Business Platform resmi, lalu server webhook HTTPS harus online. Baca `whatsapp-agent-server/README.md` untuk persyaratan Meta, konfigurasi `.env`, dan uji webhook.

Setelah server aktif, Android digunakan sebagai dashboard kendali di **Pengaturan → AGANA WhatsApp Agent**. Token server, token Meta, dan API key AI adalah kredensial berbeda. API key Android sengaja **tidak otomatis disalin ke server**.

Konteks chat antar pesan disimpan di **server**, sedangkan transaksi/Piutang/Service Android tetap di **SQLite lokal** dan tidak dibagikan otomatis. Untuk data status transaksi individual, agen mengarahkan pelanggan ke admin sampai integrasi server terverifikasi tersedia.

## Status validasi

- Pengujian Node webhook/agen: dapat dijalankan via `cd whatsapp-agent-server && node --test`.
- Struktur source/diff dan file ZIP diuji statis.
- **Compiler Flutter tidak tersedia di lingkungan penyusunan paket; APK belum diuji.** GitHub Actions akan mengecek kompilasi dan tests.
- Tidak ada login/perangkat WhatsApp Meta yang sudah tersambung; butuh konfigurasi pengguna untuk mengaktifkan live bot.


## AGAN PONSEL v1.2.0 Build22
- Koreksi pembayaran dengan alasan dan jejak audit sebelum/sesudah.
- Tanggal per barang/bon dan tombol Tambah Bon ke piutang pelanggan yang sama.
- Penyesuaian tanggal jatuh tempo, salin ringkasan piutang, aktivitas bon tambahan.
- Migrasi SQLite v11 dan kompatibilitas backup v4..v11.
- Build21 WhatsApp dan plugin preferences override tetap dipertahankan.


## AGAN PONSEL v1.3.0 Build23 — Google Drive & Alarm Piutang
- OAuth Google (`drive.file`) dengan setup Android + Web Client ID milik pemilik aplikasi.
- Backup JSON SHA-256 yang sama dengan backup manual, diupload ke folder AGAN PONSEL Backups; tidak ada auto-restore.
- Jadwal harian/mingguan/bulanan, jam target, pilihan Wi-Fi saja, retensi 7/14/30 file, cek status berhasil/gagal dan Backup Sekarang.
- WorkManager memeriksa jadwal di background; waktu eksekusi tidak dijamin tepat karena kebijakan Android dan jaringan.
- Alarm ringkasan piutang belum lunas: terlambat, hari H, 1 hari dan 3 hari sebelumnya, maksimal sekali sehari.
- Izin notifikasi Android diminta pengguna; alarm tidak menyimpan data pelanggan di server.
- Database SQLite tetap v11; tidak mengganti atau menghapus data historis.
