# AGAN PONSEL — Flutter Offline UI v0.2 (source)

Desain mengacu pada mockup 10 layar AGAN PONSEL (header biru, kartu berwarna, menu utama dan bottom navigation). Arsip `gan(2).zip` hanya digunakan sebagai referensi fitur; file autentikasi, kredensial, session WhatsApp, `node_modules`, PHP dan server **tidak** disalin.

## Sudah diimplementasikan
- Dashboard dengan metrik SQLite dan menu cepat
- Kasir sederhana: tambah produk dan penjualan langsung per item; stok berkurang dalam transaksi SQLite
- Produk & stok, tambah produk dan ubah stok
- Service HP, pencatatan dan perubahan status
- Pelanggan, pengeluaran, transaksi digital sebagai **pencatatan saja**
- Laporan ringkas semua periode
- Pengaturan informasional

## Belum diimplementasikan
Keranjang multi-item, diskon, metode bayar, struk cetak, backup/restore, printer Bluetooth, autentikasi/PIN, riwayat transaksi rinci, laporan filter tanggal, sinkronisasi desktop, WhatsApp otomatis, pulsa otomatis. Jangan gunakan untuk transaksi produksi sebelum fitur backup dan pengujian selesai.

## Build APK (GitHub Actions atau komputer dengan Flutter)
Proyek ini adalah paket source Flutter, **bukan APK teruji**. Flutter SDK resmi dibutuhkan untuk membangun folder `android/` platform yang tidak disertakan dalam paket.

```sh
flutter create --platforms=android --project-name agan_ponsel .
flutter pub get
flutter build apk --release
```

File APK (jika build berhasil): `build/app/outputs/flutter-apk/app-release.apk`.

Database `agan_ponsel_v1.db` tersimpan pada ruang privat aplikasi. Menghapus data aplikasi atau uninstall dapat menghapus database.
