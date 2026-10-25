# AGAN PONSEL v1.9.0 — Build 29 Premium Cash Card

Patch source untuk **repository Build 28 (1.8.0+28)**. Tidak berisi APK siap pasang.

## Fitur

- **8 desain kartu saldo premium**: Signature Blue, Obsidian Black, Aurora Violet, Emerald Elite, Ocean Sapphire, Rose Gold, Royal Indigo, Graphite Silver.
- Satu komponen kartu yang dipakai di **Beranda** dan **Dompet Kas Toko**, sehingga desainnya konsisten.
- Pilihan **ukuran normal / kartu ringkas**, tombol ganti desain, refresh saldo, dan tampil/sembunyikan saldo.
- Halaman pengaturan tersedia pada **Menu → Pilihan Kartu Premium**, **Pengaturan → Desain Kartu Saldo**, dan ikon palet kartu.
- Gaya kartu dan kepadatan disimpan di SharedPreferences (`cash_card_style`, `cash_card_density`) dan disertakan dalam backup; status saldo ditampilkan/disamarkan tetap khusus HP (`cash_balance_visible`).
- **Tidak ada migrasi SQLite**. Database tetap v15. Fitur ini tidak mengubah catatan kas, pinjaman, laporan, atau metode pembayaran.

## Instalasi menggunakan Termux

```sh
cd ~/agan-build/agan_ponsel_flutter
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.9.0-Build29-Patch.zip
python3 scripts/apply_build29.py
python3 scripts/check_build29.py
python3 scripts/smoke_cash_card_settings.py
python3 scripts/selftest_build29_patch.py
git diff --check
git add lib scripts test pubspec.yaml .github/workflows/build-apk.yml README-BUILD29.md
git commit -m "AGAN PONSEL v1.9.0 Build29 Premium Cash Card"
git push origin main
```

Lihat Actions pada https://github.com/adelibra23/agan-ponsel-flutter/actions. Jangan menghapus data atau uninstall aplikasi lama. Sebaiknya ekspor backup sebelum update.

## Batasan pengujian

Skrip Python menguji perubahan source, kompatibilitas data dan pengaturan. **Flutter SDK dan perangkat Android asli belum digunakan di lingkungan pengemasan**. Keberhasilan kompilasi APK harus dibuktikan GitHub Actions; warna/lay out harus diuji di HP.
