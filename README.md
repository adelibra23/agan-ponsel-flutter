# AGAN PONSEL Flutter — v0.9.0 Build 13

Proyek Android Flutter/Dart untuk operasional konter AGAN PONSEL, dikembangkan dari v0.8.0 Build 12. Semua fitur lokal lama tetap tersedia; tambahan AI internet **opsional**. Tidak ada API key dalam ZIP ini.

## Ikon aplikasi & splash

- **Ikon baru AG Orbit**: aset `assets/branding/agan_launcher.png` dan adaptive foreground `assets/branding/agan_foreground.png` 1024 × 1024. Ikon dari aset tidak menggantikan logo toko kustom pengguna (profil/nota).
- `flutter_launcher_icons` menghasilkan ikon Android berbagai densitas dan versi adaptive ketika workflow berjalan.
- `flutter_native_splash` menghasilkan tampilan statis awal dengan latar biru gelap sampai Flutter tampil.
- Splash di `lib/main.dart` menggunakan animasi Flutter: efek perspektif *simulasi 3D* pada ikon, orbit elips berputar, nebula glow, bintang, transisi posisi dan transparansi. Ini bukan objek/model 3D yang dirender engine 3D terpisah.

## AGANA AI Connect

Buka **Pengaturan → AGANA • Pengaturan API** atau **Menu Lainnya → Pengaturan API Key AGANA**. Tersedia:

| Penyedia | Model awal | Situs membuat key |
| --- | --- | --- |
| OpenRouter | `openrouter/free` | https://openrouter.ai/keys |
| Gemini AI Studio | `gemini-2.5-flash` | https://aistudio.google.com/apikey |
| Groq Cloud | `openai/gpt-oss-20b` | https://console.groq.com/keys |

Penyedia dapat memiliki kuota gratis terbatas. Tidak semua model gratis; jika mengganti ID model, periksa harga dan ketersediaan model pada akun penyedia. Tidak ada API gratis tanpa batas yang dijamin. Kuota, ketentuan, dan daftar model dapat berubah sewaktu-waktu.

**Cara pakai:** pilih penyedia → buat API key melalui tautan resmi → tempel key → pilih model → Simpan → Uji Koneksi → aktifkan **AI internet** bila siap. Teks jawaban bisa dibuat ringkas untuk penghematan token. Jangan membagikan API key melalui chat atau screenshot.

**Cara kerja:** AGANA memprioritaskan perintah yang dikenali mesin lokal (stok, service, piutang, pelanggan, tambah pengeluaran/tugas) dengan akses SQLite dan persetujuan sebelum menyimpan. Untuk pertanyaan umum yang tidak dikenali sebagai perintah lokal, jika AI internet aktif, hanya *pesan yang diketik* dan instruksi sistem dikirim via HTTPS ke penyedia. Daftar pelanggan, foto, saldo, isi SQLite, serta PIN tidak diunggah otomatis. Jawaban AI tidak pernah langsung menjalankan update ke database. Saat jaringan, key, atau kuota bermasalah, ada respons fallback lokal.

**Penyimpanan key:** kunci di `flutter_secure_storage` (Android Keystore-backed storage), **tidak** di SQLite, source, atau backup JSON aplikasi. Tombol hapus hanya menghapusnya di HP (bukan di akun penyedia). Key bisa terekspos pada HP yang dikompromikan; untuk penggunaan banyak perangkat atau distribusi publik, sebaiknya pindahkan request melalui backend/proxy dengan autentikasi dan pembatasan kuota.

## Kebutuhan Android dan build

- Flutter stable, Android SDK, JDK 17 (disiapkan GitHub Actions), minSdk Android 24.
- Plugin tambahan: `http`, `flutter_secure_storage`, `url_launcher`, `flutter_launcher_icons`, `flutter_native_splash`.
- Script `scripts/prepare_android.py` menambahkan izin Android INTERNET secara idempoten. Skrip menjaga identitas paket saat menyiapkan platform.
- GitHub Actions menjalankan `dart run flutter_launcher_icons`, `dart run flutter_native_splash:create`, pemeriksaan label, tes Dart, analisis, build APK dan unggah artifact.
- SQLite tetap **schema v8**, tidak memerlukan migrasi tabel baru. File backup lama tetap didukung dengan mekanisme versi sebelumnya.

## Instal via Termux

Lihat `INSTALL-TERMUX.txt`. Tidak perlu menjalankan Flutter SDK ARM64 di Termux. Gunakan Termux untuk Git dan GitHub Actions untuk kompilasi Android.

## Status pengujian

File aset telah dibuat dan skrip source/struktur/asset diverifikasi secara statis. **Belum ada build APK versi 0.9.0 yang dikompilasi di lingkungan ini**. Periksa workflow GitHub Actions; mungkin perlu perbaikan kesalahan API Flutter plugin/versi jika build gagal. Perilaku biometrik, perangkat fisik, dan sambungan API ber-key nyata belum diuji.

**Pembaruan di HP:** jangan uninstall aplikasi lama yang menyimpan transaksi. Lakukan backup dan pastikan ID paket serta tanda tangan APK cocok—build cloud dengan kunci penandatanganan yang berubah dapat ditolak Android sebagai pembaruan.
