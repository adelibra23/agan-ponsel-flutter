# AGAN PONSEL v1.0.2 Build 19 — Hotfix Aplikasi Tidak Bisa Dibuka

Paket source ini melanjutkan v1.0.1 Build 18 dan mempertahankan modul kasir, service, piutang, printer thermal, nota gambar, dan AGANA.

## Memasang melalui Termux (source proyek yang sudah ada)

1. Unduh `AGAN-PONSEL-Flutter-v1.0.2-Build19-Startup-Hotfix.zip` ke folder Download Android.
2. Jalankan:

```bash
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.0.2-Build19-Startup-Hotfix.zip
python3 scripts/check_startup_safety.py  # opsional, hanya jika Python tersedia

git add lib pubspec.yaml scripts .github/workflows/build-apk.yml README.md CHANGELOG.md INSTALL-TERMUX.txt assets test
git commit -m "AGAN PONSEL v1.0.2 Build19 Startup Hotfix"
git push origin main
```

3. Buka Actions pada repo GitHub untuk memeriksa build dan unduh artifact.

## Jika masih tidak terbuka

- Jangan uninstall, clear storage, atau hapus data. Database lokal tidak otomatis aman jika dihapus.
- Jika muncul layar **Pemulihan AGAN PONSEL**, tekan **Salin Error** lalu kirim pesan error tersebut.
- Jika hanya splash lalu menutup sendiri, atau Android menampilkan **Aplikasi terus berhenti**, perlu **logcat Android**; error native tidak terlihat dari hasil `flutter analyze`.
- Instal APK baru hanya jika signature aplikasi cocok; jangan uninstall aplikasi lama yang berisi data penting.

## Keamanan

PIN tidak dihapus dan tidak dilewati apabila pengecekan pengaturan keamanan gagal. Proses pemulihan SQLite hanya membuat tabel/kolom yang hilang (IF NOT EXISTS / pemeriksaan PRAGMA), tidak menghapus piutang atau service.

## Status

Validasi dasar source dan tes SQLite dapat dilakukan di lingkungan penyiapan. Kompilasi APK dan masalah perangkat fisik belum dapat dipastikan sebelum GitHub Actions dan pengujian HP.

---

# AGAN PONSEL Flutter v1.0.0 Build 17 — Nota Piutang Digital & Thermal

Lanjutan dari **v0.9.3 Build 16**, tetap memakai Dart/Flutter dan SQLite Android. Tidak membutuhkan server untuk mencatat data toko, membuat PNG atau mencetak via printer thermal yang telah dipasangkan.

## Yang baru

- **Nota digital**: empat template dengan logo toko, nama pelanggan, nomor nota stabil `AGP-000001`, tanggal, rincian barang, status pembayaran, jumlah cicilan, total dan sisa piutang, footer/kontak toko.
- **Buat PNG** dari render Flutter dengan `RepaintBoundary`, bukan teks/screenshot palsu; simpan ke lokasi Android yang dipilih (melalui dialog sistem).
- **Bagikan gambar** menggunakan Android Share Sheet (`share_plus`). Pilih WhatsApp lalu penerima secara manual. Aplikasi tidak dapat menjamin sekaligus membuka nomor tertentu dan menyertakan foto melalui API WhatsApp resmi; tombol **WhatsApp: Kirim Pesan Teks** yang lama tetap dapat menuju nomor secara langsung.
- **Printer thermal Bluetooth Classic / ESC-POS** 58 mm dan 80 mm, menggunakan pilihan printer yang sudah disimpan di Pengaturan. Cetak thermal berupa teks monokrom dengan ukuran sesuai lebar kertas; gambar berwarna hanya untuk nota digital.
- **Riwayat aktivitas nota**: log `print_dispatched`, `image_saved`, dan `share_sheet_opened` dengan tanggal dan template. Ini tidak membuktikan nota telah keluar dari printer atau pesan benar-benar diterima pelanggan.
- Migrasi SQLite **v9 → v10** menambahkan tabel `receivable_receipt_events` tanpa menghapus data lama. Data tabel dan template baru ikut backup JSON.

## Cara memakai

1. Buka **Piutang Pelanggan → Detail Piutang**.
2. Ketuk **Lihat & Bagikan Gambar Nota (PNG)**.
3. Pilih template **Classic Blue**, **Clean White**, **Dark Premium**, atau **Agan Store Modern**.
4. Pilih **Simpan PNG**, **Bagikan Gambar** (kemudian pilih WhatsApp dan kontak), atau **Print Thermal Bluetooth**.
5. Untuk print tanpa membuka preview, ada tombol **Print Thermal 58 / 80 mm** pada detail piutang.
6. Jika printer belum tersambung, pergi ke **Pengaturan → Printer Bluetooth**, lakukan pairing di Android, pilih printer dan ukuran kertas.

## Upgrade via Termux + GitHub Actions

1. Simpan ZIP di folder **Download** HP.
2. Jalankan perintah di bawah pada Termux:

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o "/sdcard/Download/AGAN-PONSEL-Flutter-v1.0.0-Build17.zip"
git add lib pubspec.yaml scripts test .github/workflows/build-apk.yml README.md CHANGELOG.md INSTALL-TERMUX.txt
git commit -m "AGAN PONSEL Flutter v1.0.0 Build17 Nota Piutang"
git push origin main
```

3. Buka https://github.com/adelibra23/agan-ponsel-flutter/actions dan lihat build baru. Unduh artifact **AGAN-PONSEL-v1.0.0-Build17-APK** bila job sukses.

## Batasan keamanan/pengujian

- Source sudah diperiksa statis dan melalui smoke test SQLite. **Belum dikompilasi dengan Flutter SDK di lingkungan pembuatan paket ini**, belum diuji di printer Bluetooth fisik atau WhatsApp. Periksa GitHub Actions dan uji fitur sebelum transaksi nyata.
- Jangan uninstall aplikasi lama sebelum backup. Pastikan **applicationId dan signing key sama** agar upgrade APK bisa mempertahankan data.
- Dokumen PNG menampilkan data pelanggan; hanya bagikan kepada penerima yang benar. Backup JSON lama masih bisa dipulihkan selama formatnya didukung.
- Riwayat share hanya mencatat saat menu Bagikan dibuka, bukan status terkirim.
