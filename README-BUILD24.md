# AGAN PONSEL v1.4.0 Build 24 — Pengeluaran & Tampilan

Patch ini **bukan source mandiri**. Pasang di atas repository **Build 23** dari GitHub, setelah melakukan commit/backup kerja lokal.

## Fitur

- Pengeluaran: daftar dan pencarian, periode hari/bulan/tahun/semua, kategori (tambah, ganti nama, arsipkan), audit global, tambah, edit tanggal+jam, metode pembayaran, catatan, detail, salin rincian, duplikasi dengan data awal terisi, konfirmasi hapus dengan alasan, CSV untuk hasil filter.
- Audit: transaksi edit & hapus dicatat terpisah dalam tabel `expense_audit`; transaksi lama tetap memiliki nominal & tanggal semula setelah migrasi.
- SQLite 11 -> 12 (additive): kolom lama `expenses` dipertahankan; tabel baru `expense_categories`/`expense_audit`. Backup JSON mencakup tabel dan font, serta menerima backup v11.
- Tema: 8 preset warna; font Android bawaan (Roboto, Sans Serif, Sans Medium, Condensed, Serif, Monospace), tanpa file font eksternal.
- Header satu baris: brand, judul halaman, cari, notifikasi; AGANA & pemindai lewat menu titik tiga.
- Hanya satu splash berlogo: native startup menggunakan gambar transparan, splash Flutter animasi bawaan tetap tampil. Android 12+ mungkin tetap menampilkan layar awal sistem sebentar—batasan OS.

## Instalasi Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
# Pastikan proyek berada di Build23 dan perubahan kerja sudah di-commit
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.4.0-Build24-Patch.zip
python3 scripts/upgrade_build24.py
python3 scripts/check_build24.py
python3 scripts/smoke_expenses_v12.py

git add lib scripts test pubspec.yaml assets/branding/splash_blank.png .github/workflows/build-apk.yml README-BUILD24.md
git commit -m "AGAN PONSEL v1.4.0 Build24 Expense Themes UI"
git push origin main
```

Build otomatis melalui https://github.com/adelibra23/agan-ponsel-flutter/actions. Unduh artifact setelah **berhasil**.

## Perhatian

- Jangan uninstall dan jangan clear data. Backup terlebih dahulu.
- Editing nominal pengeluaran langsung memengaruhi total kas dan pengeluaran laporan (tetap dijalankan dari tabel `expenses`).
- Penghapusan menghapus transaksi dari laporan/kas, tetapi menyimpan alasan & riwayat pada `expense_audit`. Audit tidak memulihkan transaksi otomatis.
- Catatan metode pembayaran adalah label; jurnal kas yang sudah ada tetap menghitung seluruh pengeluaran. Ini mengikuti perilaku lama, bukan sistem rekonsiliasi rekening bank.
- `dart format`, `flutter analyze`, `flutter test`, dan build APK belum dijalankan di lingkungan authoring; GitHub Actions akan melakukan validasi tersebut.
