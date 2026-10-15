# AGAN PONSEL Flutter v0.8.0 Build 12 — AGANA

- AGANA, asisten perintah bahasa Indonesia di perangkat, dengan UI percakapan modern.
- Baca piutang/jatuh tempo, produk/stok, status service, laporan, dan saldo kas bila tidak disembunyikan.
- Tambah pelanggan, catat pengeluaran, piutang baru, dan tugas menggunakan draft + konfirmasi pengguna.
- Aksi kompleks diarahkan ke formulir lama, bukan melakukan perubahan tanpa persetujuan.
- SQL migration v7 → v8: tabel `agent_activity` (jenis aksi dan waktu), tanpa menyimpan teks chat/nomor HP.
- Backup JSON mencakup tabel audit; restore format lama tetap bisa diproses.
- Akses AGANA dari kartu Beranda, menu Lainnya, dan ikon header.
- Tes parser perintah dan SQL migration smoke test ditambahkan.
- Tidak ada pengiriman data ke layanan AI cloud. Build APK belum diverifikasi untuk Build 12.

---

# AGAN PONSEL Flutter v0.7.0 Build 11

- ADD: Piutang & Jatuh Tempo, reminder center, riwayat cicilan, pelunasan.
- ADD: Template tampilan (Biru Orbit, Midnight, Emerald, Sunset), pesan penagihan.
- ADD: Notifikasi angka jatuh tempo pada header, kartu ringkasan piutang di Beranda.
- UI: Splash AG Orbit Motion dengan halo animasi dan transisi logo.
- UI: Kata offline hanya tampil di Tentang Aplikasi.
- DATA: Skema SQLite versi 7, migrasi aditif; backup & restore piutang dan preferensi tema.
- CASH: Cicilan Tunai masuk ke estimasi saldo kas (transfer/e-wallet dikecualikan).
- REMINDER: Ditampilkan di aplikasi ketika dibuka, belum push notification di background.

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
