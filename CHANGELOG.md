# AGAN PONSEL v1.1.0 Build 21 — AGANA WhatsApp Agent & API Key

- Pengaturan API key AGANA: kunci terenkripsi yang sudah disimpan otomatis terisi kembali ketika halaman dibuka atau penyedia diubah. Kolom tertutup secara default dan dapat dibuka melalui ikon mata. Setelah Simpan/Uji kolom tidak dikosongkan lagi.
- Menambah tombol **AGANA • WhatsApp Agent** pada menu Lainnya dan Pengaturan → AI.
- Form pengaturan WhatsApp: URL server HTTPS, token admin terenkripsi di Android, uji koneksi, sakelar balasan otomatis, daftar percakapan tersamar, alih ke admin, dan lanjutkan agen.
- Backend Node.js untuk **WhatsApp Business Platform Cloud API** dengan webhook HMAC, percakapan kontekstual, beberapa pilihan AI provider, penyimpanan lokal server dengan retensi 7 hari, deduplikasi pesan, admin handoff, penolakan STOP, dan endpoint kendali admin.
- Backend tidak terhubung langsung ke SQLite HP dan tidak mampu membaca chat WhatsApp pribadi. Perlu token Meta, server HTTPS aktif, dan API key AI server sendiri.
- Tests Node (`node --test`) dipasang di GitHub Actions untuk memverifikasi webhook, autentikasi admin, dan percakapan.
- Tetap mempertahankan penguncian `shared_preferences_android: 2.4.28` dari Startup Hotfix Build 20.
- Belum ada pengujian APK fisik/Cloud API Meta live; backend diuji dengan mock API.


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
