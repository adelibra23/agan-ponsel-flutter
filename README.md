# AGAN PONSEL Flutter Offline v0.5.0 Build 7

Aplikasi Android Flutter (Dart) untuk operasional toko AGAN PONSEL, dengan SQLite lokal.
**Source-only; build dan pengujian perangkat masih diperlukan.**

## Desain & alur
- Header baru: AG Orbit, gradasi biru ke cyan, indikator *offline*, tombol scan cepat, cari, stok menipis.
- Bottom navigation animasi Beranda, Kasir, Produk, Service, Lainnya.
- Kasir multi-item, diskon, struk, printer ESC/POS Bluetooth Classic (memerlukan printer yang kompatibel).
- Service HP bertahap, status, histori, pembayaran, teknisi dan estimasi selesai.
- Profil lokal, keuangan, laporan, stok, transaksi digital (pencatatan saja).

## Fitur baru
1. **Scan barcode**: menu Produk & Stok atau Kasir -> tombol pemindai. CameraX ML Kit berjalan offline. Mendukung EAN, UPC, QR, ITF dan Code 128.
2. **Foto produk**: tambah/edit produk -> ambil dari galeri atau kamera. Foto disimpan pada dokumen privat Android; tidak diupload ke internet.
3. **SKU cerdas**: tombol otomatis atau scan label. Duplikat kode ditolak untuk produk berbeda.
4. **Keamanan & PIN**: Menu Lainnya / Pengaturan -> Keamanan & PIN. PIN 6 digit (salted iterative SHA-256), jeda 30 detik setelah 5 percobaan salah. Mengunci saat masuk aplikasi dan setelah 20 detik di latar belakang.
5. **Backup & Restore**: foto ikut masuk ke JSON backup v2 (dengan SHA-256). Restore dapat membaca backup v1 dari database v4, tetapi foto tidak ada pada backup lama. Batas total file backup 50MB; jangan gunakan backup JSON sebagai berkas terenkripsi.
6. **Laba/unit** ditampilkan saat mengubah harga modal dan jual.

## Struktur data / migrasi
SQLite `agan_ponsel_v1.db` tidak dihapus, versi skema naik 4->5, menambah satu kolom `products.photo_file` dengan default string kosong. Data lama tetap digunakan.

## Keamanan dan keterbatasan
- PIN hanya mengunci antarmuka; tidak mengenkripsi SQLite, data gambar, atau backup JSON.
- Smartphone dengan akses root dapat membuka data lokal. Tanpa server, lupa PIN tidak bisa direset lewat email.
- Backup berisi data pelanggan/IMEI/foto, simpan hanya di lokasi tepercaya.
- Barcode scanner kamera dan printer Bluetooth wajib diuji pada HP Android dan perangkat fisik.
- **APK belum dikompilasi maupun dites di sesi ini**. GitHub Actions akan memvalidasi.
- Jangan uninstall versi lama yang berisi data; backup sebelum migrasi dan perhatikan tanda tangan APK.

## Build APK memakai HP + Termux
Lihat [INSTALL-TERMUX.txt](INSTALL-TERMUX.txt). Proses kompilasi dilakukan pada GitHub Actions, bukan langsung di Termux ARM64.

## Developer build
`flutter create --platforms=android --project-name agan_ponsel .`
`python3 scripts/prepare_android.py`
`flutter pub get`
`dart format lib test`
`flutter analyze --no-fatal-infos --no-fatal-warnings`
`flutter test test/format_test.dart test/feature_test.dart`
`flutter build apk --release`
