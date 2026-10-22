# AGAN PONSEL v1.5.0 Build 25 — Pengeluaran Pro

**Patch hanya untuk repository Build24 yang terakhir SUKSES di GitHub** (`01c05731e3fabc74efee7eeb44e52510dcab316f` atau checkout Build24 yang setara). Jangan pakai untuk Build22/23.

## Fitur

- Form **Catat Pengeluaran** dan **Edit Pengeluaran**: nama, **harga satuan**, **jumlah**, **total otomatis** (harga × jumlah), penerima/supplier, nomor nota/ref, kategori, metode, tanggal, jam, catatan, alasan koreksi.
- **Tab kategori horizontal** yang bisa digeser; ikon dan warna tampil di tab, transaksi dan pilihan kategori.
- **Tambah/edit kategori** dengan 12 ikon dan 8 pilihan warna; arsip kategori tetap tersedia. Data kategori disimpan di SQLite, bukan hanya warna sementara.
- Detail transaksi serta ekspor CSV menyertakan harga, jumlah, toko, referensi. Audit perubahan masih aktif.
- **SQLite 12 → 13**, hanya tambah kolom. Migrasi lama: jumlah = 1 dan harga satuan = nominal lama. Total historis tidak diubah. Backup JSON mencatat versi 13 dan tetap menerima backup versi sebelumnya.
- Versi aplikasi `1.5.0+25`.

## Panduan Termux

1. Backup data AGAN PONSEL terlebih dahulu. **Jangan uninstall, jangan hapus data**.
2. Pastikan repo lokal sudah berada di commit Build24 yang berhasil (termasuk Hotfix 1–3):

```bash
cd ~/agan-build/agan_ponsel_flutter
git status --short
grep '^version:' pubspec.yaml
```

3. Unduh ZIP Build25 ke `Download` HP lalu jalankan:

```bash
cd ~/agan-build/agan_ponsel_flutter
unzip -o "/sdcard/Download/AGAN-PONSEL-Flutter-v1.5.0-Build25-Patch.zip"
python3 scripts/apply_build25_meta.py
python3 scripts/check_build25.py
python3 scripts/smoke_expenses_v13.py
python3 scripts/check_build24.py
python3 scripts/smoke_expenses_v12.py
```

4. Jika berhasil, push:

```bash
git add lib/core/database.dart lib/services/expenses_service.dart lib/services/backup_service.dart lib/screens/expenses_v2.dart test/build24_expenses_test.dart scripts/apply_build25_meta.py scripts/check_build25.py scripts/smoke_expenses_v13.py scripts/check_build24.py pubspec.yaml .github/workflows/build-apk.yml README-BUILD25.md
git commit -m "AGAN PONSEL v1.5.0 Build25 Expense Pro Categories"
git push origin main
```

5. Periksa https://github.com/adelibra23/agan-ponsel-flutter/actions. Artifact sukses bernama `AGAN-PONSEL-v1.5.0-Build25-APK`.

## Catatan

- Metode pembayaran hanya metadata dan tidak otomatis memindahkan dana bank/e-wallet.
- Pengeluaran lama dibaca sebagai 1 × total, tidak dibulatkan/dibagi.
- Kategori yang diarsipkan masih tercatat dalam transaksi lama.
- Input nilai maksimal Rp1 triliun total dan jumlah maksimal 9.999 item per transaksi.
- Snapshot/backup cloud bukan terenkripsi secara otomatis; atur izin akun Drive dengan aman.
- Pengujian Python memeriksa migrasi serta struktur source. **Flutter compilation and real-device UI are not verified until GitHub Actions and device testing succeed.**
