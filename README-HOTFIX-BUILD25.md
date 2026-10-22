# AGAN PONSEL v1.5.0 Build 25 — CI Hotfix 1 (Restore Whitelist Smoke Test)

Perbaikan khusus GitHub Actions run #30 (`02c29fd15738ae944d243e5cfab324d463a97fdd`).

## Penyebab

`dart format lib test` berjalan sebelum smoke tests. Kode pemulihan backup di
`lib/services/backup_service.dart` memuat whitelist versi SQLite 4–13.
Pengujian lama menggunakan pola regex yang mengharuskan pemanggilan `.contains`
berada dalam satu baris. Setelah formatter mengatur ulang baris, regex tidak
menemukan whitelist dan menghentikan CI dengan pesan:

`AssertionError: Backup must declare allowed legacy database versions`

## Perubahan

- `scripts/smoke_receivable_details.py`: pencarian whitelist tahan terhadap
  whitespace/newline dan koma opsional pada pemanggilan `.contains`.
- `scripts/smoke_receipt_v10.py`: perbaikan serupa.
- Kedua pengujian tetap **memeriksa seluruh versi backup 4 sampai versi SQLite
  saat ini**, agar kompatibilitas restore tidak diabaikan.
- **Tidak ada perubahan** pada SQLite, backup, source aplikasi Flutter, PIN,
  payment, dan riwayat pengeluaran.

## Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o "/sdcard/Download/AGAN-PONSEL-Build25-SQLite-CI-Hotfix1.zip"
python3 scripts/smoke_receivable_details.py
python3 scripts/smoke_receipt_v10.py
python3 scripts/smoke_receivable_v11.py
python3 scripts/smoke_expenses_v12.py
python3 scripts/smoke_expenses_v13.py
git diff --check
git add scripts/smoke_receivable_details.py scripts/smoke_receipt_v10.py README-HOTFIX-BUILD25.md
git commit -m "Fix Build25 backup version smoke regex"
git push origin main
```

## Status

Diuji dengan Python stdlib dan data SQLite contoh di lingkungan pembuatan
paket; termasuk variasi whitelist multiline hasil pemformatan Dart.
Tidak diklaim APK berhasil sampai GitHub Actions **Build release APK** dan
**Upload installable APK artifact** sukses.

**Jangan uninstall aplikasi lama atau hapus data toko.**
