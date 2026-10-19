# AGAN PONSEL v1.0.2 Build 19 — Startup Recovery Hotfix

- Memperbaiki potensi aplikasi tertahan di pemeriksaan PIN: timeout 10 detik, tombol **Coba Lagi**, dan mode aman yang tidak melewati PIN.
- Menambah layar pemulihan ketika inisialisasi SQLite gagal; menampilkan error yang dapat disalin untuk diagnostik.
- Memulihkan percobaan pembukaan SQLite setelah gagal, serta memeriksa skema tambahan tanpa menghapus data lama.
- Menambah layar informasi jika SharedPreferences gagal dibaca saat aplikasi mulai berjalan.
- Menjaga ikon splash tetap memiliki fallback bila aset gagal ditampilkan.
- Menjalankan ulang penyiapan tema Android setelah `flutter_native_splash` dalam GitHub Actions.
- Memasukkan perbaikan import Build 18 (`ReceivableLine`) ke source penuh.
- Tidak mengubah skema SQLite 10; data piutang dan riwayat nota tetap tersedia.

**Keterbatasan:** Ini adalah hardening startup; sumber crash native Android belum dapat dipastikan tanpa logcat HP. Jangan uninstall atau hapus data aplikasi. Build melalui GitHub Actions dan uji pada perangkat sebelum pemakaian produksi.

---

# AGAN PONSEL v1.0.0 Build 17 — Nota Piutang Digital

- Fitur nota piutang gambar PNG dengan 4 template profesional serta logo toko.
- Ekspor PNG dengan pemilih lokasi Android dan bagikan gambar ke WhatsApp melalui sistem Share Sheet.
- Print thermal ESC/POS 58 mm atau 80 mm, tersedia di layar preview dan detail piutang.
- Kartu aksi Detail Piutang yang membedakan WhatsApp teks, nota PNG, dan thermal.
- Riwayat perintah cetak, simpan PNG dan pembukaan panel Bagikan (bukan status terkirim).
- Migrasi SQLite v10: `receivable_receipt_events`.
- Backup menambahkan event nota dan preferensi template, restore backup v4–v10 didukung.
- Unit test format nota thermal, subtotal, status pembayaran dan nomor nota.
- Workflow GitHub Actions memuat smoke test migrasi v10, test nota, dan artifact Build 17.

**Status:** source siap untuk build GitHub Actions; APK/printer belum diuji pada perangkat fisik.
