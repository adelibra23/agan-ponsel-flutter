# AGAN PONSEL Flutter v1.2.0 Build22 — Koreksi Pembayaran & Bon Bertanggal

**Paket ini adalah overlay untuk proyek Build21 (v1.1.0+21) di GitHub.** Jangan gunakan ZIP Build17 sebagai base; jangan hapus directory proyek. Paket hanya memuat file yang berubah dan mempertahankan kode AGANA WhatsApp Build21, startup guard, serta hotfix shared_preferences_android 2.4.28.

## Pembaruan

- **Koreksi riwayat pembayaran:** ubah jumlah, metode Tunai/Transfer/E-Wallet, tanggal, dan catatan. Alasan minimal 5 karakter, konfirmasi ulang, dan riwayat lama/baru tersimpan dalam `receivable_payment_edits`; audit tidak diedit/hapus lewat UI.
- **Validasi saldo atomik:** hasil koreksi tidak boleh membuat total bayar > total tagihan; pembayaran lainnya tidak berubah, tidak membuat pembayaran negatif.
- **Bon tambahan pelanggan yang sama:** tombol Tambah Bon pada halaman detail mengisi item baru dengan tanggal tiap barang, harga, qty, serta dapat memperbarui jatuh tempo. Tidak membuat duplikat pelanggan atau menghapus cicilan. Piutang versi lama akan dinormalisasi sebagai satu item historis pada penambahan bon pertama.
- **Riwayat tambahan bon:** tabel `receivable_bon_events` mencatat nominal, waktu, dan jumlah barang yang ditambahkan.
- **Tanggal item pada nota:** tercetak di format thermal dan terlihat di gambar PNG berwarna.
- **Salin Ringkasan Piutang:** tanggal per item, kuantitas, nominal, total, cicilan, sisa, dan tenggat ke clipboard.
- **SQLite versi 11** dengan migrasi aditif dan pembaruan backup JSON. Cadangan versi database 4-11 tetap diterima selama format valid; tabel koreksi juga disertakan saat ekspor.

## Instalasi menggunakan HP & Termux

1. Buat backup data toko pada aplikasi lama terlebih dahulu. Jangan uninstall ataupun hapus data sebelum memastikan cadangan.
2. Pastikan repo sudah di **Build21** dan memiliki hotfix startup. Buka Termux:

```bash
cd ~/agan-build/agan_ponsel_flutter
grep '^version:' pubspec.yaml
grep 'shared_preferences_android: 2.4.28' pubspec.yaml
test -f lib/screens/settings/whatsapp_agent_settings.dart && echo 'Build21 AGANA WhatsApp ditemukan'
```

3. Harus tertulis versi `1.1.0+21`, preferences `2.4.28`, dan Build21 AGANA ditemukan. Jika benar, letakkan ZIP pada Download, lanjut:

```bash
unzip -o "/sdcard/Download/AGAN-PONSEL-Flutter-v1.2.0-Build22-Patch.zip"
python3 scripts/upgrade_build22.py
python3 scripts/smoke_receivable_v11.py
python3 scripts/smoke_receivable_details.py
python3 scripts/smoke_receipt_v10.py
python3 scripts/check_labels.py

git add lib scripts test pubspec.yaml .github/workflows/build-apk.yml README.md CHANGELOG.md
git commit -m "AGAN PONSEL v1.2.0 Build22 Payment Correction and Dated Bon"
git push origin main
```

4. GitHub Actions akan membuat APK. Verifikasi build **AGAN-PONSEL-v1.2.0-Build22-APK** sukses sebelum memasang.

## Penting

- **Jangan uninstall APK yang sudah ada** karena data lokal mungkin hilang. Instal sebagai pembaruan jika applicationId dan signing key sama.
- Beri tahu jika muncul pesan `Merge/Conflict` atau `Build error`; jangan memaksa hapus data.
- Koreksi pembayaran mengubah saldo piutang, namun **tidak otomatis membuat jurnal penyesuaian kas**. Jika transaksi fisik kas/bank sudah dicatat terpisah, sesuaikan pencatatan kas secara manual.
- Riwayat audit lokal dapat berubah jika pengguna mengganti seluruh database lewat restore backup. Tidak dimaksudkan sebagai audit forensik yang tidak dapat dimanipulasi.
- Tes Python SQLite tidak menguji Flutter widget, R8, printer fisik, atau APK Android. Periksa hasil GitHub Actions dan uji pada HP.
