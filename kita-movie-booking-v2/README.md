# K.I.T.A Movie Booking v2 — SK Seri Mendapat

Versi ini mengubah aliran kepada **free seating** dan **penetapan hall oleh admin**.

## Fungsi v2
- Murid pilih kelas dan nama daripada senarai pramuat; tidak menaip nama sendiri.
- Murid pilih tarikh, sesi dan filem yang telah ditetapkan oleh admin.
- Admin menetapkan filem + Hall A/B bagi setiap sesi.
- Kapasiti: Hall A = 40, Hall B = 35. Sistem menutup tempahan apabila penuh.
- Tiada pemilihan nombor kerusi atau rekod nombor kerusi. Murid memilih tempat duduk fizikal sendiri apabila masuk ke hall.
- Seorang murid hanya boleh menempah satu filem bagi satu sesi. Sesi lain boleh ditempah secara berasingan.
- Admin melihat senarai tempahan dan menandakan bayaran sebagai dibayar.
- Harga tiket RM1; Pakej Adik RM3; Pakej Abang RM5.

## Penting: privasi senarai murid
Untuk membolehkan dropdown nama berfungsi tanpa log masuk murid, fungsi kelas/nama dalam SQL ini boleh dicapai oleh pelawat laman. Ini mendedahkan senarai nama murid. **Jangan lancarkan pautan awam sebelum sekolah meluluskan kaedah akses.** Untuk penggunaan sebenar, disyorkan tambah PIN individu / kod akses sekolah atau hadkan tempahan melalui peranti/akaun yang dikawal sekolah. Jangan masukkan nombor IC, alamat atau data sensitif.

## A. Supabase
1. Buka Supabase project yang digunakan oleh laman.
2. SQL Editor → jalankan `supabase/schema-v2.sql`.
3. Table Editor → jadual `students` → Import data from CSV → pilih `supabase/students-import.csv`.
4. Pastikan pemetaan lajur ialah `student_name` dan `class_name`. CSV mengandungi 98 nama daripada fail senarai murid yang dibekalkan.
5. Authentication → Users: cipta akaun admin.
6. Salin UUID admin dan jalankan:
   ```sql
   insert into public.admins(user_id, display_name)
   values ('UUID-ADMIN', 'Admin K.I.T.A');
   ```
7. Dalam `assets/js/app.js`, masukkan Project URL dan anon/public key. **Jangan sekali-kali letak service_role key dalam laman web.**

## B. Tetapkan filem dan hall
1. Log masuk ke butang Admin di laman.
2. Pilih sesi, filem dan hall.
3. Simpan tetapan.
4. Ulang untuk setiap filem/hall/sesi yang hendak dibuka.
5. Dalam satu sesi, Hall A dan Hall B boleh menayangkan dua filem berlainan. Satu hall hanya boleh mempunyai satu filem bagi satu sesi.
6. Jika hall sudah mempunyai tempahan, sistem menghalang pertukaran filem/hall supaya rekod tempahan tidak tersalah kait.

Kapasiti automatik ditetapkan: Hall A 40, Hall B 35. Jangan ubah kapasiti melalui UI.

## C. Terbitkan di GitHub Pages
Muat naik **kandungan folder ini** ke root repository (pastikan `index.html` di root). Jika repo sedia ada menggunakan fail lama, gantikan `index.html`, `assets/js/app.js`, tambah `supabase/schema-v2.sql` dan `supabase/students-import.csv`; kekalkan `assets/css/style.css` dan poster dalam `assets/images/`.

## D. Aliran murid
Pilih kelas → pilih nama → pilih tarikh → pilih sesi → pilih filem yang tersedia → pilih pakej makanan (pilihan) → hantar. Tiket QR dan nombor rujukan dipaparkan. Tiada nombor kerusi diberikan.

## E. Ujian sebelum dibuka
- Uji satu tempahan untuk setiap hall.
- Uji tempahan murid sama pada dua filem dalam sesi sama (mesti ditolak).
- Uji tempahan murid sama dalam sesi berlainan (mesti dibenarkan).
- Uji had 40 untuk Hall A dan 35 untuk Hall B.
- Uji admin mark paid.
- Uji pada telefon dan komputer.

## Jadual sedia ada
- 20 Nov 2026: Sesi 1 08:00–10:00; Sesi 2 10:30–12:00.
- 23 Nov 2026: Sesi 1 10:30–12:30; Sesi 2 12:30–13:30.
- 24 Nov 2026: Sesi 1 10:30–12:30; Sesi 2 12:30–13:30.

## Struktur
```text
kita-movie-booking-v2/
├── index.html
├── README.md
├── assets/css/style.css
├── assets/js/app.js
├── assets/images/poster-karnival-kita.jpeg
└── supabase/
    ├── schema-v2.sql
    └── students-import.csv
```
