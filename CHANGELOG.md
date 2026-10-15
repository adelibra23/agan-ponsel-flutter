# AGAN PONSEL Flutter — Changelog

## v0.6.1 Build 10 — Contrast & Dashboard Polish

- Perbaikan warna semua judul dan label menu agar sesuai light/dark theme, khususnya kategori Pengaturan dan Tentang Aplikasi.
- TextTheme/ColorScheme berbasis warna onSurface dan onSurfaceVariant dengan kontras lebih tinggi.
- Menu item, kartu pengaturan, dan nama ikon di Beranda mengikuti token warna tema.
- Kartu statistik, kartu sapaan, saldo, dan target omzet Beranda diperbarui dengan border lembut, tipografi modern, serta animasi yang lebih halus.
- Unit test rasio kontras untuk teks utama dan sekunder.
- Tidak ada migrasi database: SQLite schema tetap versi 6, data lokal tetap digunakan.


## v0.6.0 Build 9 — Offline Plus

- Kontak pelanggan dari buku telepon Android (izin baca saja, dipilih satu per satu)
- Pengaturan logo toko dan preview logo di header/profil
- Saldo kas tercatat dan riwayat setoran/pengambilan, tombol sembunyikan saldo
- Target omzet harian dengan indikator pencapaian
- Tugas dan catatan toko menggunakan SQLite
- PIN + biometrik Android (wajah/sidik jari sesuai dukungan perangkat)
- Typography/branding header lebih rapi
- SQLite skema 6, migrasi additive (produk, tiket service, transaksi tetap)
- Backup JSON v3 membawa foto produk, logo, target harian, kas dan tugas; restore kompatibel v1/v2
- Izin Android READ_CONTACTS, USE_BIOMETRIC dan host FlutterFragmentActivity
- `flutter_contacts` 1.x dan `local_auth` 2.x untuk memastikan API plugin kompatibel

## v0.5.1 Build 8

- Hotfix parser PIN `List<int>` dan import helper halaman pengaturan PIN; build GitHub Actions sukses.

## v0.5.0 Build 7

- Barcode scanner, foto produk, PIN, identitas visual AGAN PONSEL.
