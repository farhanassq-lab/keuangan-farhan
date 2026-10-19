# Farhan Finance V3 — GitHub Pages bundle

Paket ini untuk memperbarui repository GitHub Pages `farhanassq-lab/keuangan-farhan` dari aplikasi Mizan Finance menjadi **Farhan Finance**.

## Pembaruan visual dan fitur
- Branding Farhan Finance pada login, dashboard, profil, judul tab, dan ikon PWA.
- Dashboard premium: deep navy/indigo, aksen mint, background ambient, kartu dengan hover halus, animasi masuk, progress bar, dan animasi count-up saldo.
- Profil pengguna dan foto profil Supabase Storage tetap tersedia.
- Target tabungan dan budget bulanan tetap tersedia.
- **Financial Pulse**: ringkasan arus kas bersih, rasio tabungan, dan status budget untuk EGP atau IDR secara terpisah.
- **Smart Reminders**: pengingat berdasarkan budget mendekati/melewati batas, tenggat target tabungan, target tabungan bulanan, atau belum ada transaksi pada bulan berjalan.
- **Mode Privasi**: tombol di header untuk menyamarkan nominal dan grafik saat membuka aplikasi di tempat umum. Preferensi disimpan lokal di perangkat; tidak mengubah data database.
- Sapaan dashboard menyesuaikan waktu lokal.
- Animasi menghormati preferensi `prefers-reduced-motion`.

## Penting sebelum upload
1. Buat backup `index.html`, `manifest.webmanifest`, `sw.js`, dan ikon lama dari GitHub.
2. Versi ini tidak menambah tabel database baru. Fitur profil/target/budget masih memerlukan migrasi V2 yang sudah disediakan di `supabase/v2_migration.sql`.
3. Jika migrasi V2 sudah pernah berhasil dijalankan pada project Supabase, **jangan jalankan ulang**; langsung unggah file web. Jika belum pernah, jalankan `supabase/v2_migration.sql` sekali di Supabase SQL Editor sebelum menggunakan fitur profil/target/budget.
4. Upload/commit file berikut ke root repository: `index.html`, `manifest.webmanifest`, `sw.js`, folder `icons/`. Folder `supabase/` boleh tetap ada di repo untuk dokumentasi/migrasi.
5. `index.html` mempertahankan Project URL dan publishable key yang dipakai versi sebelumnya. Jangan mengganti dengan placeholder. Jangan pernah menaruh `service_role`/secret key di frontend.
6. Tunggu GitHub Pages deploy. Tutup PWA dari recent apps dan buka kembali. Jika tampilan lama masih tersimpan, buka situs di Chrome dan lakukan refresh; service worker V3 memakai cache namespace baru.

## Struktur file
```text
repository-root/
├── index.html
├── manifest.webmanifest
├── sw.js
├── icons/
│   ├── icon-192.png
│   └── icon-512.png
└── supabase/
    └── v2_migration.sql
```

## Checklist uji
- Login memakai akun yang sudah ada.
- Pastikan saldo dan transaksi lama tidak berubah.
- Ubah profil/foto jika migrasi V2 sudah dijalankan.
- Buat atau buka target tabungan dan budget.
- Uji Financial Pulse dengan memilih EGP lalu IDR.
- Aktifkan mode privasi, pastikan nominal dan grafik tersamarkan, lalu nonaktifkan lagi.
- Periksa pengingat budget dan tenggat target.
- Pastikan aplikasi tetap berfungsi di layar HP.

## Keamanan
- Mode privasi hanya menyamarkan tampilan di perangkat; ini bukan pengganti logout atau pengamanan perangkat.
- Semua data finansial tetap di Supabase dan membutuhkan internet untuk disinkronkan.
- Pastikan RLS tetap aktif. Jangan membagikan password, session token, atau service-role key.
