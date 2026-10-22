# AGAN PONSEL Build 24 — Hotfix 2 (SQLite smoke tests)

Dibuat untuk commit Build 24 yang sudah menerima **Hotfix 1** dan mencapai langkah `Smoke test receivable detail migration`, lalu gagal akibat `assert 'version: 11' in code`.

## Perbaikan

Empat skrip pengujian, **tanpa perubahan kode aplikasi atau database**:

- `scripts/smoke_receivable_details.py` — memastikan migrasi v9 masih didukung, sambil menerima versi database >= 9 dan menjaga kompatibilitas backup lama.
- `scripts/smoke_receipt_v10.py` — memeriksa migrasi v10 dengan aturan yang sama.
- `scripts/smoke_receivable_v11.py` — memastikan tanggal bon dan audit pembayaran v11 tetap ada pada database versi lebih baru.
- `scripts/check_build23.py` — memeriksa integrasi cloud/alarm tanpa mengunci nama artifact atau `pubspec` ke Build 23.

Tidak perlu menurunkan SQLite v12 menjadi v11. Fitur pengeluaran, kategori, tema, splash, Google Drive, dan alarm tidak diganti.

## Termux (setelah ZIP diunduh ke folder Download)

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Build24-SQLite-CI-Hotfix2.zip
python3 scripts/smoke_receivable_details.py
python3 scripts/smoke_receipt_v10.py
python3 scripts/smoke_receivable_v11.py
python3 scripts/check_build23.py
python3 scripts/check_build24.py
python3 scripts/smoke_expenses_v12.py
git add scripts/smoke_receivable_details.py scripts/smoke_receipt_v10.py scripts/smoke_receivable_v11.py scripts/check_build23.py README-HOTFIX-BUILD24-2.md
git commit -m "Fix Build24 legacy SQLite smoke checks"
git push origin main
```

Build APK dijalankan lewat GitHub Actions. Jika proses masih gagal pada langkah lain, lihat log build terbaru. **Jangan uninstall aplikasi lama, hapus data, atau menjalankan ulang upgrade Build 24.**

## Pengujian

Smoke test SQLite v9, v10, v11 dan v12 serta pemeriksaan Build24 lolos pada salinan source lokal. Semua token integrasi yang diperiksa `check_build23.py` ditemukan pada source Build24 di GitHub. **Flutter build / analisis Dart belum dijalankan di lingkungan pembuat patch**.
