# AGAN PONSEL Flutter v0.8.0 • Build 12

Aplikasi manajemen konter HP berbasis Dart/Flutter, dengan SQLite pada perangkat Android. Source ini dikembangkan dari Build 11 (v0.7.0), yang sudah pernah berhasil dibangun menggunakan GitHub Actions. Build 12 masih perlu diuji oleh workflow dan pada HP fisik.

## Baru: AGANA — Asisten Pintar Toko

AGANA adalah **agen perintah lokal dengan pola bahasa Indonesia**, bukan model AI generatif yang bisa memahami semua instruksi. Tidak memerlukan kunci API/server dan tidak mengirim data toko ke layanan AI eksternal.

Fitur baca data:
- `cek tagihan Budi`: mencari piutang aktif pelanggan yang tersimpan.
- `siapa yang jatuh tempo`: melihat piutang yang terlambat atau jatuh tempo dalam 3 hari.
- `cek stok charger` atau `stok menipis`: nama, stok, harga, batas minimum.
- `cek service Andi`: status tiket service yang sudah tercatat.
- `laporan hari ini` / `laporan`: omzet, estimasi laba kotor, pengeluaran, service dan stok.
- `saldo kas`: menghormati tombol sembunyikan saldo; tidak membuka angka bila disembunyikan.

Fitur tambah data lewat pesan, **wajib dikonfirmasi sebelum disimpan**:
- `tambah pelanggan Budi 081234567890`
- `catat pengeluaran 25000 untuk isolasi`
- `tambah catatan pesan LCD Redmi Note 12`
- `catat piutang Budi; 150000; 2026-11-01; pembelian pulsa`

Bila diminta tindakan kompleks seperti `buat service`, `tambah produk`, `bayar piutang`, atau `ubah jatuh tempo`, AGANA mengarahkan ke formulir yang telah tersedia. Tidak otomatis memindahkan uang, top up, membayar tagihan provider, mengirim WhatsApp, maupun memotong stok tanpa transaksi kasir.

AGANA bisa dibuka dari kartu di **Beranda**, ikon bintang di **header**, atau **Menu Lainnya**. Riwayat percakapan hanya berada di memori layar selama sesi, tidak otomatis disimpan. Tabel `agent_activity` merekam *jenis* perubahan yang disetujui, bukan isi pesan, nomor, atau PIN.

## Keamanan dan data

- Data disimpan di SQLite versi **8**, yang menambah tabel `agent_activity` dan mempertahankan tabel lama.
- Backup & Restore JSON menyertakan tabel baru serta data dari versi sebelumnya. File backup **tidak terenkripsi**.
- Semua tindakan tulis lewat AGANA butuh tombol **Setujui & Simpan**. Pembuatan pelanggan, pengeluaran, piutang, dan catatan memakai transaksi SQLite bersama audit.
- AGANA mematuhi pengaturan visibilitas saldo kas.
- PIN/biometrik antarmuka tetap tersedia, tetapi tidak mengenkripsi database.
- Kata “offline” tidak dimunculkan di halaman selain Tentang Aplikasi.

## Fitur yang tetap ada

Kasir & struk, inventory barcode/foto, service HP, pelanggan & kontak, buku kas, laporan, piutang/jatuh tempo, template warna, AG Orbit splash, printer Bluetooth, PIN/biometrik, logo toko, backup & restore, pengeluaran, tugas, transaksi digital (pencatatan), dan mode gelap.

## Instal source / build APK via Termux + GitHub

Lihat `INSTALL-TERMUX.txt`. Tidak perlu memasang Flutter SDK pada Termux. Build dilaksanakan GitHub Actions. Simpan backup data penting dan jangan uninstall APK lama sebelum memastikan keystore penandatanganan pembaruan cocok.

## Batas pengujian

Pemeriksaan source, referensi import, aturan label dan SQL dilakukan saat paket dibuat. `flutter analyze`, unit test Dart, kompilasi APK, dan pengujian Android belum dijalankan pada Build 12. Gunakan GitHub Actions dan kirim log pertama yang gagal bila ada.
