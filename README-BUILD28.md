# AGAN PONSEL Flutter v1.8.0 — Build 28

Patch sumber **di atas Build27 v1.7.0+27**, bukan APK. Jangan gunakan pada checkout Build25/26 dan jangan uninstall APK toko.

## Fitur

- **Catatan & Tugas:** tambah/edit/hapus, kategori, prioritas, jatuh tempo manual, sematkan, filter, cari, checklist, salin teks dan bagikan via Android share sheet.
- **Dompet Kas:** tombol Analisis Buku Kas, total setoran/pengambilan manual, filter dan ekspor CSV.
- **Laporan:** rentang tanggal kustom, omset, laba kotor penjualan, biaya admin digital sukses, pengeluaran, estimasi hasil; salin dan CSV.
- **Pulsa & Transaksi Digital:** pencarian, filter status, referensi, catatan, metode pembayaran, berbagi detail, edit status dan riwayat perubahan; nominal dan fee transaksi lama tetap tidak dapat diedit untuk mencegah koreksi tanpa audit keuangan.
- **Produk:** insight nilai modal stok, potensi omzet/margin, stok habis dan menipis, ekspor CSV inventaris.

## Database dan kompatibilitas

- SQLite **v15** bersifat additive: metadata `store_notes`, metadata `digital_transactions`, dan tabel riwayat `digital_events`.
- Data lama tidak dibuang; catatan lama mendapat kategori `Umum`, prioritas `Normal`, dan transaksi digital lama berstatus `Selesai`.
- Backup mendukung database versi 4–15; tabel audit baru termasuk dalam snapshot.
- Laporan pendapatan biaya admin hanya menghitung transaksi digital dengan status `Selesai`. Menandai `Gagal` dapat mengubah estimasi laporan, tetapi **tidak mengoreksi kas eksternal secara otomatis**.
- Informasi tenggat Catatan hanya ditandai **dalam aplikasi**, bukan alarm Android terjadwal. Alarm Piutang yang sudah ada tetap terpisah.
- Angka margin stok merupakan perkiraan berdasarkan harga input; bukan laba aktual.

## Pemasangan via Termux

```bash
cd ~/agan-build/agan_ponsel_flutter
# Disarankan buat backup repo atau commit pekerjaan sebelum ekstrak.
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.8.0-Build28-Patch.zip
python3 scripts/apply_build28.py
python3 scripts/check_build28.py
python3 scripts/smoke_operations_v15.py
python3 scripts/selftest_build28_patcher.py
python3 scripts/verify_patch_fixture.py
python3 scripts/smoke_receivable_details.py
python3 scripts/smoke_receipt_v10.py
python3 scripts/smoke_receivable_v11.py
python3 scripts/smoke_expenses_v13.py
python3 scripts/smoke_restock_v14.py
git diff --check
git add lib scripts test pubspec.yaml .github/workflows/build-apk.yml README-BUILD28.md
git commit -m "AGAN PONSEL v1.8.0 Build28 Store Operations"
git push origin main
```

GitHub Actions lalu menjalankan `dart format`, smoke tests, `flutter analyze`, Flutter unit tests dan build release Android.

## Batas pengujian

Diuji tanpa Flutter SDK: Python syntax, SQLite DDL fixture, migrasi/retensi data lama, pengulangan patch, serta pemeriksaan struktur file. **Belum diuji** Flutter Analyze, build APK, perilaku plugin share/file picker di HP Android, dan penggunaan riil sampai GitHub Actions selesai.

## Keamanan data

1. Cadangkan data AGAN PONSEL melalui aplikasi lama sebelum update.
2. Jangan uninstall aplikasi lama, jangan hapus data, jangan ubah package name atau signing key.
3. Untuk file CSV berisi pelanggan/transaksi, simpan ke lokasi pribadi yang dipercaya.
4. Jika GitHub Actions gagal, periksa step yang gagal; jangan berulang kali menjalankan patch lama.
