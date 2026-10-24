# AGAN PONSEL v1.7.0 Build 27 — Restock & Supplier

Pembaruan source Flutter yang melanjutkan **Build 26** (atau Build 25 jika Build 26 belum dipasang, melalui dua langkah di bawah). Fokus: mempermudah pengadaan barang konter tanpa mengubah catatan penjualan maupun uang kas secara diam-diam.

## Fitur

- **Pusat Restock & Supplier** di Menu Lainnya; tiga tab: Stok Menipis, Rencana Pembelian, Supplier.
- **Deteksi stok minimum otomatis**, saran beli hingga target 2× stok minimum, estimasi modal dari harga pokok produk.
- **Kontak supplier**: tambah/edit nama, telepon, alamat, dan catatan.
- **Rencana pembelian** dengan pemilihan supplier, item, jumlah dan estimasi harga yang diambil dari harga modal terbaru produk. Status `draft`, `received`, `cancelled`.
- **Salin daftar belanja** dan tombol **WhatsApp supplier** untuk menyusun pesan. Pengguna sendiri yang memeriksa penerima lalu mengirim.
- **Konfirmasi barang diterima**: setelah persetujuan, stok ditambah sekali dan setiap pergerakan dicatat ke `stock_movements`. Semua diproses dalam satu transaksi SQLite.
- Membuat rencana atau konfirmasi penerimaan **tidak mengurangi kas dan tidak membuat transaksi Pengeluaran**. Catat biaya pembelian pada Pengeluaran bila benar-benar dibayar; hal ini menghindari jurnal ganda.

## Pembaruan database

- SQLite **v13 → v14**, tabel tambahan `suppliers`, `restock_orders`, `restock_order_items`.
- Tidak menghapus atau mengubah isi tabel produk, penjualan, piutang, service, stok lama, maupun pengeluaran.
- Tabel baru ikut ke backup JSON/SHA-256 dan pemulihan menerima database backup historis v4–v14.
- Semua DDL `CREATE TABLE IF NOT EXISTS` sehingga pembukaan ulang aman.

## Cara memasang melalui HP + Termux

Lakukan backup data AGAN PONSEL sebelum memasang APK baru, dan **jangan uninstall/clear data aplikasi lama**.

Unduh `AGAN-PONSEL-Flutter-v1.7.0-Build27-Combined-Patch.zip` ke folder `/sdcard/Download/`. Paket ini mencakup patch Build 26 yang belum dikirim ke GitHub beserta fitur Build 27.

```bash
cd ~/agan-build/agan_ponsel_flutter
# Disarankan commit pekerjaan lokal yang belum disimpan sebelum upgrade.
unzip -o /sdcard/Download/AGAN-PONSEL-Flutter-v1.7.0-Build27-Combined-Patch.zip
python3 scripts/apply_build26.py
python3 scripts/apply_build27.py
python3 scripts/check_build27.py
python3 scripts/smoke_restock_v14.py
python3 scripts/smoke_budget_backup.py
python3 scripts/smoke_receivable_details.py
python3 scripts/smoke_receipt_v10.py
python3 scripts/smoke_receivable_v11.py
python3 scripts/smoke_expenses_v12.py
python3 scripts/smoke_expenses_v13.py

git diff --check
git add lib scripts test pubspec.yaml .github/workflows/build-apk.yml README-BUILD26.md README-BUILD27.md
git commit -m "AGAN PONSEL v1.7.0 Build27 Restock Supplier"
git push origin main
```

Jika kamu **sudah menjalankan Build 26**, `apply_build26.py` aman dijalankan kembali pada source Build 26 yang sesuai. `apply_build27.py` juga aman diulang setelah berhasil.

Lihat hasil di `https://github.com/adelibra23/agan-ponsel-flutter/actions`. Artifact target `AGAN-PONSEL-v1.7.0-Build27-APK` hanya akan tersedia jika keseluruhan job sukses.

## Keselamatan & batas pengujian

- Petugas harus memverifikasi stok fisik dan supplier sebelum menekan **Konfirmasi Barang Diterima**. Konfirmasi bersifat final untuk rencana tersebut agar stok tidak ganda.
- Tidak ada penyetoran kas atau pembayaran otomatis dari rencana pengadaan. Nilai modal hanyalah estimasi.
- Riwayat stok mencatat `Restock #ID` untuk audit.
- Data supplier adalah informasi pribadi/komersial; bagikan hanya kepada tujuan yang dimaksud. Gunakan akun Google Drive pribadi jika mengaktifkan backup cloud.
- Pengujian yang tersedia di paket ini berupa tes statis dan SQLite in-memory. **Flutter Analyze, unit test Flutter, build APK release, dan pengujian di perangkat asli baru akan terverifikasi lewat GitHub Actions/HP.**
