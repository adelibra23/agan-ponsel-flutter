# AGAN PONSEL – Flutter Offline v0.3.0 (Build 3)

Aplikasi Android berbasis Flutter / Dart, dibuat dari arah desain AGAN PONSEL yang disepakati: identitas biru modern, splash animasi **AG Orbit**, header gradient, transisi halaman halus, dan bottom nav pill animasi. Referensi fitur: sistem desktop/server `gan(2).zip`; **kode sesi autentikasi, gateway WhatsApp, dan rahasia dari arsip lama tidak disertakan**.

## Tersedia

- **Dashboard**: omzet, laba kotor, jumlah transaksi hari ini, jumlah service aktif, notifikasi stok menipis.
- **Kasir**: pencarian + filter kategori, keranjang multi-produk, tambah/kurangi qty, diskon, pembayaran tunai/transfer/e-wallet (pencatatan), pengurangan stok atomik, struk teks yang bisa disalin.
- **Produk & Stok**: tambah dan edit produk, kategori, SKU, batas minimum stok, riwayat pergerakan stok.
- **Service HP**: nomor tiket, nama pelanggan, nomor telepon, perangkat, keluhan, estimasi biaya, perubahan status/antrian.
- **Pelanggan**: menambah dan mencari kontak.
- **Pulsa & Digital**: mencatat nominal, nomor tujuan, biaya admin untuk berbagai jenis layanan; **tidak otomatis mengirim pulsa/transfer**.
- **Pengeluaran**: catat dan jumlahkan biaya toko.
- **Laporan**: ringkasan harian/semua waktu, omzet, laba kotor penjualan, admin digital, pengeluaran dan estimasi hasil bersih (belum termasuk pajak, piutang, atau keuntungan service).
- **Riwayat kasir**: daftar 40 transaksi baru, detail struk dan salin ke clipboard.
- **Pengaturan**: tema terang/gelap yang tersimpan lokal di HP.
- **Offline**: menggunakan SQLite privat aplikasi. Tidak butuh komputer atau jaringan saat aplikasi digunakan.

## Migrasi data (penting)

Database lokal tetap menggunakan nama `agan_ponsel_v1.db` dan dinaikkan ke **schema versi 3**. Tabel v0.2 seperti `products`, `sales`, `services`, `customers`, `expenses`, `digital_transactions` dipertahankan. Produk mendapat atribut `category`, `sku`, `min_stock`. Tabel baru `receipts`, `receipt_items`, `stock_movements` ditambah tanpa menghapus tabel lama.

> **Jangan uninstall aplikasi lama atau pilih Clear Storage** jika berisi data penting. Migrasi hanya terjadi jika upgrade APK dengan **applicationId dan kunci signing kompatibel**. Build melalui GitHub Actions memakai signing debug bawaan Flutter; kunci dapat berubah jika build dilakukan pada runner baru. Oleh sebab itu **jangan mengandalkan update APK tanpa backup**. Fitur backup dan restore masih belum tersedia di versi ini. Untuk data produksi tunggu mekanisme ekspor/impor dan signing stabil.

## Pasang source lewat Termux (tanpa Python)

1. Unduh ZIP `AGAN-PONSEL-Flutter-v0.3.0-Build3.zip` dari chat dan simpan ke folder **Download** HP.
2. Di Termux yang sebelumnya sudah mempunyai clone GitHub `agan-ponsel-flutter`:

```bash
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v0.3.0-Build3.zip

git status --short
git add lib pubspec.yaml README.md .github/workflows/build-apk.yml
git commit -m "AGAN PONSEL Flutter v0.3.0 Build3 Modern UI"
git push origin main
```

3. Buka repo GitHub → **Actions** → jalankan workflow atau tunggu trigger otomatis `push` → buka run sukses → unduh artifact `AGAN-PONSEL-v0.3.0-Build3-APK` → ekstrak → instal `app-release.apk`.
4. Jika `git push` muncul `Could not resolve host: github.com`, perbaiki koneksi data/Wi-Fi/DNS; commit sudah tersimpan, ulang hanya `git push origin main`.

**Jika Termux belum bisa menerima izin penyimpanan:** jalankan `termux-setup-storage` lalu izinkan akses file. Kalau repo lokal belum ada, jalankan `git clone https://github.com/adelibra23/agan-ponsel-flutter.git` dalam folder kerja kamu.

## Build di komputer (opsional)

```bash
flutter create --platforms=android --project-name agan_ponsel .
flutter pub get
dart format lib
flutter analyze
flutter build apk --release
```

## Batasan build

Source telah ditinjau dan diperiksa pasangan delimiter serta tokennya, **tetapi tidak dikompilasi atau diuji runtime di lingkungan penyiapan paket** (Flutter SDK/Android SDK tidak tersedia). GitHub Actions akan melakukan pemeriksaan Dart, analisis dan build sebenarnya. Jika error, gunakan baris error pertama dari langkah `Format and check Dart syntax` atau `Analyze Flutter code`/`Build release APK`.

## Rencana berikutnya

Backup/restorasi terenkripsi/JSON, printer struk Bluetooth thermal, edit/hapus dengan arsip audit, barcode kamera, piutang, pembayaran nyata melalui provider yang berizin, QR login/sinkronisasi server opsional. Fitur-fitur ini **belum diimplementasikan**.
