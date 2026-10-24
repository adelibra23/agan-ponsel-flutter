# AGAN PONSEL v1.7.0 Build27 — Analyze Flutter Hotfix 2

GitHub Actions run #33 gagal saat `flutter analyze`: **2 error** pada
`lib/screens/restock_center.dart` (setelah formatter: baris 551):

- `missing_required_argument`: named parameter `context` harus diisi.
- `extra_positional_arguments_could_be_named`: context dikirim secara posisional.

Perbaikan: `showDialog<bool>(context, builder:` menjadi
`showDialog<bool>(context: context, builder:`.

## Install (Termux)

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o "/sdcard/Download/AGAN-PONSEL-Build27-Analyze-Hotfix2.zip"
python3 scripts/apply_build27_hotfix2.py
python3 scripts/check_build27_hotfix2.py
git diff --check
git add lib/screens/restock_center.dart scripts/apply_build27_hotfix2.py scripts/check_build27_hotfix2.py README-HOTFIX-BUILD27-2.md
git commit -m "Fix Build27 restock showDialog named context"
git push origin main
```

**Tidak mengubah SQLite, backup, produk, piutang, saldo, PIN, atau paket Android.**
Pengujian skrip lokal bukan bukti berhasilnya kompilasi APK; tunggu hasil Actions.
