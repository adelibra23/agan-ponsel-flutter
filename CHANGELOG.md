# v0.9.3 Build 16 — Piutang Rinci & Navigasi Persisten

- Detail piutang: preview dan kirim pengingat WhatsApp, edit pelanggan, telepon, tagihan, catatan, dan jatuh tempo.
- Form piutang baru: banyak baris, harga satuan per barang, kuantitas, subtotal dan total otomatis.
- Pilih kontak Android read-only di form piutang; nomor pelanggan terisi otomatis, tanpa impor massal.
- Piutang lama: dapat diedit menjadi rincian item; cicilan tidak pernah dihapus oleh pengeditan.
- Upgrade SQLite v8 ke v9 dengan tabel `receivable_items` + indeks; backup tetap kompatibel versi lama.
- Tab utama tidak dibuat ulang saat pindah: `IndexedStack` stabil dan `PageStorageKey` pada sejumlah daftar.
- Migrasi smoke test Python, pengujian unit untuk total item dan nomor WhatsApp, update pipeline Actions.
- Mencakup hotfix dependensi dan `StateError` dari Build 14–15.

# AGAN PONSEL v0.9.0 Build 13 — AG Orbit 3D & AGANA AI Connect

- Ikon AGAN PONSEL baru AG Orbit dengan adaptive launcher icon, disimpan sebagai aset PNG tinggi-resolusi; ikon Android diproses saat build.
- Splash screen Android native bersenyawa warna biru gelap, dilanjutkan animasi perspektif 3D bergaya hologram di Flutter, glow, orbit elips, bintang, dan transisi masuk.
- Halaman **AGANA • Pengaturan AI**: OpenRouter Free Router, Gemini AI Studio, Groq Cloud; model editable, key pribadi, tombol tampil/sembunyi, uji koneksi, hapus key, mode jawaban ringkas, aktif/nonaktif.
- Kunci API disimpan pada flutter_secure_storage, bukan source, SQLite, atau backup JSON; panggilan API lewat HTTPS ke domain penyedia yang dibatasi.
- AGANA menjalankan perintah operasional pada SQLite lebih dulu. Pertanyaan bebas tak dikenal dapat diproses via AI internet bila diaktifkan; tidak ada akses cloud otomatis ke catatan toko atau eksekusi mutasi database.
- Opsi pengaturan API ditambah pada halaman Pengaturan, Menu Lainnya, dan ikon di layar AGANA.
- SQLite tetap versi 8; fitur sebelumnya, keamanan PIN/biometrik, barcode, piutang, kas, printer, dan backup tetap ada.
- Workflow ditambah generator launcher icon/native splash dan tes daftar provider; izin INTERNET di AndroidManifest.

## Batasan

Ketersediaan model/kuota gratis tergantung penyedia, model, wilayah, dan waktu. Build Android/HTTP runtime belum diuji. Animasi 3D berupa simulasi perspektif, bukan model 3D eksternal. Pengaturan key langsung dari Android cocok untuk proyek pribadi/BYOK, bukan distribusi key server milik toko ke banyak instalasi.
