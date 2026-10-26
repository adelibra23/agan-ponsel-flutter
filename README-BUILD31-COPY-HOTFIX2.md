# AGAN PONSEL Build 31 — Visible Copy Hotfix 2

Hotfix untuk kegagalan GitHub Actions `Validate visible copy` pada Build 31.

**Penyebab:** halaman Tentang dipindah ke `lib/screens/settings/about_store.dart`, sedangkan `scripts/check_labels.py` masih mengharapkan kata "offline" di `lib/screens/settings/settings_pages.dart` yang sekarang hanya berfungsi sebagai route wrapper.

## Perubahan

- Teks **Tentang Aplikasi** kini menjelaskan bahwa pencatatan utama dapat dipakai secara offline dengan data tersimpan lokal, sedangkan Google Drive, AGANA API, dan WhatsApp membutuhkan internet.
- Pemeriksaan `scripts/check_labels.py` dipindahkan ke target **halaman Tentang yang sebenarnya** dan tetap melarang kata "offline" di bagian/halaman lain.
- Tidak mengubah DB SQLite v15, data pelanggan, kas, piutang, PIN, backup, autentikasi, atau pilihan tema.

## Termux (jalankan pada repository Build 31 yang sudah ada)

```bash
cd ~/agan-build/agan_ponsel_flutter
unzip -o '/sdcard/Download/AGAN-PONSEL-Build31-Visible-Copy-Hotfix2.zip'
python3 scripts/apply_build31_labels_hotfix.py
python3 scripts/check_labels.py
python3 scripts/check_build31_labels_hotfix.py
python3 scripts/check_build31.py
git diff --check
git add lib/screens/settings/about_store.dart scripts/check_labels.py scripts/apply_build31_labels_hotfix.py scripts/check_build31_labels_hotfix.py README-BUILD31-COPY-HOTFIX2.md
git commit -m 'Fix Build31 About offline copy and visible labels CI'
git push origin main
```

`dart format lib test`, `flutter analyze`, test Flutter, dan build APK harus diverifikasi melalui GitHub Actions. Jangan hapus data aplikasi atau uninstall APK lama.
