# AGAN PONSEL Flutter — Changelog

## v0.5.0 Build 7 (15 Oktober 2026)

- Header biru premium baru, tombol scan cepat, indikator *offline*, aksen cyan, dan animasi AG Orbit.
- Barcode/QR scanner kamera offline dari produk, kasir, dan header. Isi kode secara manual jika kamera tidak tersedia.
- Foto produk dari galeri atau kamera disimpan privat di Android dan tampil di daftar produk dan kasir.
- SQLite schema v5: kolom `photo_file`, indeks lama dipertahankan; pemeriksaan barcode/SKU ganda.
- Pembuatan kode SKU otomatis dan kalkulasi estimasi laba per unit pada editor produk.
- Kunci aplikasi PIN 6 digit: hash salted, perlambat brute force, batas percobaan, kunci setelah dari latar belakang 20 detik.
- Backup JSON versi 2 menyertakan file foto produk dalam payload, dukungan restore backup v4 lama, validasi nama file dan ukuran.
- Permission kamera dan Android minSdk 24 dikonfigurasi oleh skrip idempotent di CI.
- Unit test dasar untuk format PIN dan nama foto aman.

Keamanan: PIN hanya melindungi antarmuka, **tidak mengenkripsi SQLite**. Backup JSON juga tidak terenkripsi.
Status: paket source disiapkan dan diperiksa secara statis; hasil Flutter analyzer / build APK belum diverifikasi.
