# AGAN PONSEL v1.6.0 Build 26 — Insight Keuangan & Anggaran

**Persyaratan:** repositori Android Flutter sebelumnya sudah Build 25 dan hotfix SQL CI sudah lulus. GitHub Actions run 31 berhasil. Build 26 adalah patch incremental, **bukan proyek mandiri**.

## Fitur

1. **Insight Pengeluaran**: total bulan ini dan bulan sebelumnya, selisih, jumlah transaksi, grafik batang horizontal enam bulan, komposisi per kategori.
2. **Anggaran bulanan**: total belanja toko dan batas kategori disimpan di SharedPreferences, dapat diedit. Warna/status memberi peringatan saat mencapai 80% dan 100% **saat halaman Insight dibuka**. Tidak mengirim alarm Android otomatis.
3. **Pengeluaran sering dicatat**: deteksi transaksi yang berulang (nama, kategori, harga, qty), satu ketukan membuka form Catat Pengeluaran dengan isian awal; pengguna harus mengonfirmasi simpan. Tidak ada auto-posting.
4. **Salin ringkasan bulanan**: teks pengeluaran serta rincian kategori siap dibagikan manual.
5. **Integrasi backup**: kunci `expense_budget_settings` ditambahkan ke profil JSON/SHA-256 backup lama; database **tetap SQLite v13** dan transaksi lama tidak diubah.

## Cara update via Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.6.0-Build26-Patch.zip
python3 scripts/apply_build26.py
python3 scripts/check_build26.py
python3 scripts/smoke_budget_backup.py
python3 scripts/smoke_receivable_details.py
python3 scripts/smoke_receipt_v10.py
python3 scripts/smoke_receivable_v11.py
python3 scripts/smoke_expenses_v12.py
python3 scripts/smoke_expenses_v13.py

git add lib/screens/expenses_v2.dart lib/screens/expense_insights.dart lib/services/expense_insights_service.dart lib/services/backup_service.dart pubspec.yaml .github/workflows/build-apk.yml scripts/apply_build26.py scripts/check_build24.py scripts/check_build25.py scripts/check_build26.py scripts/smoke_budget_backup.py test/build26_insights_test.dart README-BUILD26.md
git commit -m "AGAN PONSEL v1.6.0 Build26 Finance Insights"
git push origin main
```

Lihat GitHub Actions di https://github.com/adelibra23/agan-ponsel-flutter/actions. Artifact tujuan: `AGAN-PONSEL-v1.6.0-Build26-APK`.

## Keamanan & batasan

- Tetap gunakan applicationId dan signing key yang sama, jangan uninstall atau hapus data aplikasi, buat backup sebelum update.
- Anggaran bukan transfer ke bank dan tidak mengubah penjualan, stok, atau piutang.
- Grafik ini hanya dari transaksi `expenses`, bukan perhitungan laba bersih.
- Backup JSON **tidak terenkripsi**; jangan dibagikan sembarangan.
- Flutter SDK tidak tersedia di lingkungan pembuatan patch; pengujian kompiler sesungguhnya dan Android/WhatsApp/Google Drive perlu diverifikasi lewat Actions/perangkat.
