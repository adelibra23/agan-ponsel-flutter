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
