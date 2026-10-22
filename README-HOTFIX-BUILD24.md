# AGAN PONSEL Build24 Hotfix 1 — Gagal Dart Format Exit 65

Log GitHub Actions run #26 menampilkan syntax errors di `lib/screens/expenses_v2.dart` baris 478–483: single-quoted Dart strings mengandung newline mentah pada riwayat audit. Dart menolak memformatnya. Peringatan `analysis_options.yaml` tentang `flutter_lints` berasal dari package yang tidak tercantum dalam pubspec.

Perbaikan:
1. `lib/screens/expenses_v2.dart` sudah diperbaiki dengan escape `\n` pada riwayat audit. Ini file yang identik dengan repo Build24 kecuali perbaikan string.
2. `scripts/apply_build24_hotfix.py` menambahkan `flutter_lints: ^6.0.0` ke `dev_dependencies` yang sudah ada secara idempoten. Tidak mengganti `pubspec.yaml`, sehingga dependensi Google Drive / alarm tetap aman.
3. `scripts/check_build24_hotfix.py` memeriksa hasil perubahan.

## Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o "/sdcard/Download/AGAN-PONSEL-Build24-Dart-Format-Hotfix1.zip"
python3 scripts/apply_build24_hotfix.py
python3 scripts/check_build24_hotfix.py
git add lib/screens/expenses_v2.dart pubspec.yaml scripts/apply_build24_hotfix.py scripts/check_build24_hotfix.py README-HOTFIX-BUILD24.md
git commit -m "Fix Build24 Dart format and flutter_lints"
git push origin main
```

Patch membutuhkan Build24 di repo, tidak untuk Build23 dan tidak mengubah database. Tidak perlu mengulang `upgrade_build24.py`.

Pemeriksaan lokal hanya untuk perbaikan teks; `dart format`, `flutter analyze`, `flutter test`, dan build APK tetap dilakukan di GitHub Actions.
