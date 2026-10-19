# AGANA WhatsApp Agent — WhatsApp Business Platform (Cloud API)

**Backend terpisah**, bukan pembaca chat WhatsApp pribadi. Source ini untuk menghubungkan nomor WhatsApp Business yang memenuhi syarat ke Meta WhatsApp Cloud API, menerima webhook pesan masuk, dan mengirim balasan AGANA dengan AI.

## Kemampuan

- Balasan chat pelanggan via **WhatsApp Business Platform** (untuk chat masuk baru; bukan spam/outbound massal).
- Memahami konteks **12 pesan terakhir** per nomor dan menyimpannya maksimal 7 hari di server.
- Otomatis memperkenalkan diri sebagai **asisten AI**, tidak menyamar sebagai pegawai manusia.
- Perintah `admin`, `operator`, `bicara dengan admin` → **jeda AI**, pelanggan menunggu admin.
- `STOP`, `jangan balas` → hentikan balasan bot untuk pelanggan tersebut. Status penolakan disimpan sebagai hash HMAC (tanpa nomor asli) hingga pelanggan mengirim `MULAI`/`START`.
- Webhook diverifikasi dengan **Meta X-Hub-Signature-256**, GET verify token, duplikat `wamid` ditolak.
- Dashboard Android dapat mengaktifkan/mematikan agen, melihat status, dan alih layanan ke admin.
- Proteksi akses admin dengan token Bearer. Nomor pelanggan ditampilkan empat digit terakhir saja di Android.
- Menjaga batas respons dalam jendela layanan pelanggan **24 jam setelah pesan masuk**. Pesan bisnis di luar jendela perlu template WhatsApp yang disetujui dan **tidak diimplementasikan** pada paket ini.

**Belum tersedia:** membaca pesan WhatsApp pribadi/WhatsApp Business app langsung dari Android, sinkronisasi SQLite HP atau data piutang/status service secara otomatis, balasan voice note/foto, broadcast/template outbound, assignment admin multi-user, retry kuat pada beberapa replika server, dan notifikasi admin proaktif. Untuk data transaksi yang berubah, agen wajib mengarahkan pelanggan kepada admin.

## Kebutuhan

1. Nomor dan akun **WhatsApp Business Platform** yang sudah didaftarkan lewat Meta Developers. Periksa opsi *coexistence* sebelum memigrasikan nomor WhatsApp Business App yang telah digunakan sehari-hari.
2. `WA_PHONE_NUMBER_ID`, akses token dengan izin `whatsapp_business_messaging`, `WA_APP_SECRET` dari pengaturan aplikasi Meta, dan `WA_VERIFY_TOKEN` buatanmu.
3. **Hosting dengan HTTPS publik** dan penyimpanan file persisten (VPS lebih mudah; jangan jalankan di Termux yang harus selalu aktif).
4. **Node.js 22+** pada hosting (tidak perlu dependensi NPM tambahan).
5. API key sendiri dari Groq, OpenRouter, atau Gemini. Paket gratis bergantung kuota dan dapat berubah.

Referensi: https://developers.facebook.com/docs/whatsapp/cloud-api/overview , https://www.postman.com/meta/whatsapp-business-platform/folder/13382743-ba8d099d-007e-4b52-b9f2-3cf3c60e4fbc

## Jalankan di server

```sh
cd whatsapp-agent-server
cp .env.example .env
# Sunting .env dan isi semua parameter yang diberi placeholder.
# Buat ADMIN_TOKEN sendiri, contoh: openssl rand -hex 32
# Buat WA_VERIFY_TOKEN sendiri, contoh: openssl rand -hex 32
node --test
node --env-file=.env server.mjs
```

Contoh reverse proxy Caddy (domain contoh, ganti dengan domainmu):

```caddyfile
wa.example.com {
  reverse_proxy 127.0.0.1:3000
}
```

Atur `HOST=127.0.0.1` bila menggunakan Caddy lokal. Jalankan dengan `systemd`/process manager yang otomatis hidup lagi. Pastikan folder `data/` di-volume persisten, hak akses terbatas, dan backup privat. **Jangan memasukkan `.env` ke GitHub**.

## Konfigurasi Meta Webhook

Set callback Meta sebagai `https://wa.example.com/webhook`, verify token = `WA_VERIFY_TOKEN`, subscribe event `messages` pada WhatsApp Business Account. Endpoint `GET /webhook` memverifikasi challenge; `POST /webhook` menolak request tanpa HMAC Meta yang sesuai.

**Pengaturan awal AI dimatikan**. Setelah token Meta, AI, domain, dan webhook berfungsi, buka APK: **Pengaturan → AGANA • WhatsApp Agent**, isi `https://wa.example.com` dan `ADMIN_TOKEN`, tekan **Simpan & Uji**, lalu **Aktifkan agen WhatsApp**.

> `ADMIN_TOKEN` adalah token administrasi server milik toko, **bukan** token Meta atau API key AI. Jangan menyimpan token Meta di aplikasi Android. API key AGANA di Android **tidak otomatis dibagikan** kepada server WhatsApp; konfigurasi `AI_API_KEY` dilakukan sekali lagi pada server.

## Pengaturan fakta toko

`SHOP_FACTS_JSON` dalam `.env` adalah sumber informasi **yang boleh dijanjikan** oleh AGANA. Hanya masukkan informasi yang benar dan tidak sensitif (alamat, jam, jenis layanan, kebijakan, harga yang sudah pasti). Jangan unggah CSV pelanggan, PIN, nota, atau SQLite dari HP. Jika stok, harga, atau status service belum tersinkron, AGANA diarahkan untuk **minta admin**.

## Keamanan dan privasi

- Percakapan disimpan **plaintext dalam file JSON di server** untuk menjaga konteks, maksimal tujuh hari. Proteksi direktori dan backup; gunakan kebijakan privasi toko yang menyebut AI pihak ketiga. Untuk produksi skala besar gunakan database terenkripsi/pengelolaan retensi dan worker antrean yang lebih kuat.
- Gunakan **HTTPS** publik dan atur password/token server melalui environment, bukan source atau URL.
- Hanya pesan teks baru; file multimedia tidak diunduh otomatis.
- Data pertanyaan dan sejumlah pesan sebelumnya diteruskan ke penyedia AI pilihanmu. Jangan melatih/memasukkan data rahasia secara otomatis tanpa izin yang sesuai.
- Setiap percakapan berisi identitas AI pada balasan pertama. Operator tetap bertanggung jawab atas klaim harga, transaksi, janji servis, dan jawaban AI.
- Server saat ini **satu proses, satu lokasi data**; jangan menjalankan dua replika dengan file JSON yang sama. Job dipersistenkan sebelum webhook di-acknowledge. Pada crash tepat setelah Meta menerima balasan tetapi sebelum status tersimpan, balasan ganda masih mungkin; gunakan antrean durable/koordinasi transaksi untuk skala produksi.
- Saat server down, tidak ada balasan otomatis. Tidak ada mekanisme bypass WhatsApp atau pengendalian kontak tanpa izin.

## Endpoint admin

Semua endpoint `/admin/` memerlukan `Authorization: Bearer <ADMIN_TOKEN>`.

| Metode | Path | Hasil |
| --- | --- | --- |
| GET | `/health` | Server hidup (publik, tanpa rahasia) |
| GET | `/admin/status` | Status agen dan nomor tersamar |
| POST | `/admin/agent` | `{ "enabled": true/false }` |
| POST | `/admin/threads/:id/handoff` | `{ "paused": true/false }` |

Jangan mencetak token ke log. Uji dengan **nomor percobaan** sebelum memakai nomor toko asli.
