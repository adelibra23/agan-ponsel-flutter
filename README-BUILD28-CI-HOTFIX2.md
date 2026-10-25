# AGAN PONSEL Build 28 — CI Hotfix 2

**Masalah:** GitHub Actions run #36 melewati migrasi SQLite, tetapi gagal di
`Check Build28 notes, finance and digital SQLite`. `dart format lib test`
memecah `SharePlus.instance.share` pada `lib/screens/store_notes.dart`
menjadi beberapa baris. Skrip `check_build28.py` mencari string yang harus
persis sama, bukan pemeriksaan yang tahan pemformatan.

**Perbaikan:** Ubah hanya `scripts/check_build28.py` sehingga SEMUA marker
integrasi Build28 masih diperiksa, dengan mengabaikan perubahan whitespace
(spasi, tab, baris baru). Semua guard SQLite tetap dijalankan.
Tidak mengubah aplikasi, data, backup, Flutter dependencies, atau workflow.

## Instalasi di Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Build28-CI-Hotfix2.zip
python3 scripts/apply_build28_ci_hotfix.py
python3 scripts/check_build28_ci_hotfix.py
python3 scripts/check_build28.py
python3 scripts/smoke_operations_v15.py
git diff --check
```

Selanjutnya:

```sh
git add scripts/check_build28.py scripts/apply_build28_ci_hotfix.py scripts/check_build28_ci_hotfix.py README-BUILD28-CI-HOTFIX2.md
git commit -m 'Fix Build28 CI checks after dart format'
git push origin main
```

Lihat GitHub Actions. Jika terjadi kegagalan lain, baca langkah pertama yang
gagal, jangan mengubah versi SQLite atau menghapus data aplikasi.

**Batasan QA:** Python smoke tests hanya menilai source dan skema contoh,
bukan kompilasi Flutter. Build release dan perangkat Android perlu diverifikasi
oleh GitHub Actions serta pengujian APK.
