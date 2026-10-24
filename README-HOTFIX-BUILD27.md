# AGAN PONSEL Build 27 — Hotfix CI Kompatibilitas Backup

Hotfix khusus **v1.7.0+27** untuk GitHub Actions run #32.

## Masalah

Langkah `Smoke test receivable detail migration` gagal pada `supported_versions` karena regex pada pengujian lama hanya mengenali `].contains(payload['databaseVersion'])` dalam satu baris. Saat workflow menjalankan `dart format lib test`, kode Dart dapat menjadi multi-baris dan parameter `contains()` dapat memperoleh koma penutup. Format kode berubah, tetapi daftar versi backup v4–v14 **tetap benar**.

## Perbaikan

- `scripts/backup_compat_check.py`: validator bersama yang membaca daftar versi pemulihan dari metode `chooseBackup()`, tidak rentan terhadap pemisahan baris dan koma penutup.
- `scripts/smoke_receivable_details.py`, `scripts/smoke_receipt_v10.py`, `scripts/smoke_budget_backup.py`, `scripts/smoke_restock_v14.py`: gunakan validator yang sama, tetapi semua tes SQL lama tetap berjalan.
- `scripts/selftest_backup_compat.py`: uji format satu/multi-baris dan kasus negatif (versi lama hilang).
- `scripts/check_build27_hotfix.py`: pastikan repository adalah Build 27, SQLite v14, backup v4–v14, dan integrasi skrip lengkap.

**Tidak mengubah** `lib/`, `pubspec.yaml`, Android, SQLite, struktur backup, penjualan, stok, dan fungsi restock.

## Termux

Pastikan sebelum ekstrak: `grep '^version:' pubspec.yaml` menampilkan `version: 1.7.0+27`.

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Build27-Backup-CI-Hotfix1.zip
python3 scripts/selftest_backup_compat.py
python3 scripts/check_build27_hotfix.py
python3 scripts/smoke_receivable_details.py
python3 scripts/smoke_receipt_v10.py
python3 scripts/smoke_receivable_v11.py
python3 scripts/smoke_budget_backup.py
python3 scripts/smoke_restock_v14.py
git diff --check

git add scripts/backup_compat_check.py scripts/selftest_backup_compat.py scripts/check_build27_hotfix.py scripts/smoke_receivable_details.py scripts/smoke_receipt_v10.py scripts/smoke_budget_backup.py scripts/smoke_restock_v14.py README-HOTFIX-BUILD27.md
git commit -m "Fix Build27 backup CI tests after dart format"
git push origin main
```

Lihat proses build di https://github.com/adelibra23/agan-ponsel-flutter/actions.

## Batasan

Script dan ZIP bisa diperiksa tanpa Flutter SDK; kompilasi Flutter/APK hanya dapat dikonfirmasi oleh GitHub Actions. Jangan uninstall aplikasi atau hapus data toko untuk masalah CI seperti ini.
