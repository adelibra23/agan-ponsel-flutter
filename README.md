# AGAN PONSEL Flutter Offline v0.6.1 • Build 10

Aplikasi **Android Flutter + SQLite**, offline tanpa server komputer. Paket ini merupakan source code lanjutan v0.5.1 Build 8; bukan APK yang sudah diuji di HP.

## Baru di Build 10 — Kontras tema & Beranda modern

- Judul kategori **Keamanan aplikasi**, **Akun & identitas toko**, **Penyimpanan & perangkat**, **Tampilan & informasi**, dan **Tentang versi ini** kini menggunakan warna `onSurface` yang menyesuaikan mode terang/gelap.
- Warna teks, label, subtitle, menu, tombol, AppBar, field, dan indikator navigasi menggunakan token warna tema yang kontras. Teks putih dipertahankan hanya pada elemen dengan latar gradasi biru.
- Komponen `SectionTitle` kini mempunyai garis aksen biru, skala 16.5 sp, dan subtitle yang mudah dibaca.
- Beranda: kartu sapaan adaptif, kartu statistik dua kolom dengan ikon terpisah, nilai angka lebih menonjol, kartu saldo yang diperhalus, animasi progress target omzet, dan tepi kartu yang lebih rapi.
- **Tidak ada perubahan skema SQLite** (tetap v6), tabel maupun data transaksi. Fitur kontak, PIN/biometrik, foto produk, barcode, printer, dan backup tetap dipertahankan.
- Menambahkan tes regresi kontras teks pada tema terang dan gelap di GitHub Actions.

## Fitur dari Build 9

- **Kontak pelanggan**: tekan ikon kontak pada menu Pelanggan, izinkan `READ_CONTACTS`, cari dan pilih satu kontak/nomor untuk menambah pelanggan. Tidak ada impor massal atau sinkronisasi otomatis. Tetap bisa input manual bila izin ditolak.
- **Logo toko**: Pengaturan → **Logo & Branding**, pilih gambar JPG/PNG/WebP dari galeri (maksimum 2 MB). Logo ditampilkan di header, profil, dan halaman tentang aplikasi; file disimpan privat di Android.
- **Saldo kas lokal**: Dashboard → kartu saldo; tekan ikon mata untuk menyembunyikan/menampilkan nominal. Saldo dihitung dari penjualan bertanda **Tunai** dalam sistem kasir modern + penyesuaian kas manual − semua pengeluaran yang tercatat. Penjualan lama, layanan digital, DP service, serta rekening bank tidak termasuk karena cara bayarnya tidak tercatat atau terhubung. Saldo dapat bernilai negatif jika pembukuan belum direkonsiliasi. Tidak ada integrasi bank atau e-wallet.
- **Buku kas**: Menu Lainnya → Saldo & Kas Toko untuk setoran/pengambilan manual dan riwayat penyesuaian.
- **PIN & Biometrik**: Pengaturan → Keamanan & PIN → aktifkan PIN 6 digit lebih dulu, kemudian verifikasi perangkat untuk mengaktifkan biometrik. Android dapat menawarkan sidik jari atau pengenalan wajah jika *secure biometrics* didukung dan didaftarkan. PIN tetap sebagai cadangan. Tidak memindahkan data wajah/jari ke aplikasi.
- **Catatan & Tugas**: checklist lokal dan hapus catatan; tersimpan SQLite.
- **Target omzet harian**: Dashboard menampilkan indikator omzet/target. Atur melalui tombol bendera pada halaman Saldo & Kas Toko.
- **Tipografi & header**: skala dan ketebalan teks konsisten, brand logo baru, indikator offline, navigasi animasi tetap dipertahankan.
- **Backup & Restore v3**: ekspor SQLite skema v6, semua tabel, foto produk, logo toko, profil, dan target omzet. Impor backup format lama v1/v2 tetap diterima. Backup JSON menggunakan checksum SHA-256, tetapi **TIDAK terenkripsi**.

## Teknologi

Dart/Flutter, `sqflite` versi skema 6, `flutter_contacts` v1 untuk pembacaan kontak, `local_auth` v2 untuk biometrik, `shared_preferences`, `image_picker`, `path_provider`, `mobile_scanner`, `print_bluetooth_thermal`.

## Cara build APK dari Android + Termux + GitHub Actions

1. Unduh ZIP Build 9, pindahkan ke folder Download ponsel.
2. Jalankan perintah dari `INSTALL-TERMUX.txt` dalam proyek yang sudah ada.
3. GitHub Actions otomatis melakukan `flutter create`, menambah izin Android, `flutter pub get`, `dart format`, `flutter analyze`, unit test dan `flutter build apk --release`.
4. Jika workflow hijau, masuk ke run → **Artifacts** → unduh ZIP APK. Bila merah, periksa **langkah pertama yang gagal**, bukan hanya baris akhir `exit code 1`.

**Peringatan data:** SQLite disimpan di area privat Android, tetapi data bisa hilang akibat uninstall/hapus data. Sebelum memperbarui APK produksi, buat backup dan pastikan nama paket Android serta sertifikat tanda tangan cocok dengan versi yang sebelumnya terpasang. GitHub runner yang membuat keystore debug baru tiap kali dapat menghasilkan APK dengan tanda tangan berbeda; APK seperti itu tidak dapat menimpa instalasi sebelumnya tanpa konfigurasi signing yang konsisten. Jangan uninstall sebelum backup terverifikasi.

**Keamanan:** Kunci PIN/biometrik melindungi antarmuka, **tidak mengenkripsi database ataupun backup**. Kontak yang dipilih akan disalin ke SQLite, dan dapat ikut diekspor bersama backup. Jangan membagikan backup mentah secara publik.

**Status:** Pembaruan source sudah dipaketkan dan skrip persiapan Android diuji secara lokal. Kompilasi Flutter serta pengujian perangkat biometrik, kontak, printer dan pemulihan data fisik belum dilakukan dalam sesi ini.


## Pembaruan v0.7.0 Build 11

- Piutang pelanggan dengan jatuh tempo, nominal, nomor kontak, catatan dan pencarian.
- Cicilan parsial, pelunasan, riwayat pembayaran, pilih metode pembayaran.
- Pusat Pengingat (jatuh tempo hari ini, lewat tempo, dan 3 hari mendatang)
  ditampilkan saat aplikasi dibuka; **belum menjadwalkan notifikasi sistem saat aplikasi ditutup**.
- Tombol salin pesan pengingat memakai template Ramah / Formal / Singkat.
- Empat template tampilan: Biru Orbit, Midnight, Emerald, Sunset. Mode gelap tetap tersedia.
- Splash AG Orbit Motion dengan efek halo berdenyut dan transisi logo.
- Teks "offline" dibatasi di halaman Tentang Aplikasi.
- SQLite migrasi v6 → v7 menambah `receivables` dan `receivable_payments`, tidak menghapus tabel lama.
- Backup JSON menyertakan kedua tabel piutang dan pilihan template.
- Pembayaran piutang **Tunai** dicatat sebagai kas masuk. Transfer dan e-wallet tidak menambah saldo kas.
- Piutang baru tidak otomatis mengurangi stok atau mencatat omzet. Kasir dan Piutang tetap transaksi terpisah.

### Upgrade dari Termux
Unduh ZIP ke folder Download, buat backup data aplikasi sebelum memperbarui APK.
Ekstrak ke root repository yang sudah ada, lalu `git add`, `git commit`, dan `git push`.
Lihat `INSTALL-TERMUX.txt` untuk langkah terinci.

**Status**: source diperiksa statis dan smoke test SQL tersedia; APK baru perlu dikompilasi dan diuji di GitHub Actions.
